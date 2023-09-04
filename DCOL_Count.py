#!/usr/bin/env python3

import sys
import argparse
import pprint
from datetime import datetime
import socket


sys.path.append("Public"); # Gave up trying to work how to do this with a .pth file or using .
#sys.path.append("/Users/gkirk/Documents/GitHub/DCOL")
#sys.path.append("/Users/gkirk/Documents/GitHub/DCOL/Public")
sys.path.append("internal");
sys.path.append("internal_stubs");

from DCOL import *
from DCOL_Decls import *


def ByteToHex( byteStr ):
    """
    Convert a byte string to it's hex string representation e.g. for output.
    """

    hex = []
    for aChar in byteStr:
        hex.append( "%02X " % aChar )

    return ''.join( hex ).strip()


class ArgParser(argparse.ArgumentParser):

    def convert_arg_line_to_args(self, arg_line):
        for arg in arg_line.split():
            if not arg.strip():
                continue
            yield arg


parser = ArgParser(
            description='Trimble Data Collector (DCOL) packet counter',
            fromfile_prefix_chars='@',
            epilog="(c) JCMBsoft 2013-2023")

parser.add_argument("-A", "--ACK", action="store_true", help="Displays ACK/NACK replies")
parser.add_argument("-U", "--Undecoded", action="store_true", help="Displays Undecoded Packets")
parser.add_argument("-D", "--Decoded", action="store_true", help="Displays Decoded Packets")
parser.add_argument("-E", "--Explain", action="store_true", help="System Should Explain what is is doing, AKA Verbose")
parser.add_argument("-G", "--GNSS", action="store_true", help="Data is from a GNSS Debug Traffic Stream. There are two bytes in front of each Packet")
parser.add_argument("-W", "--Time", action="store_true", help="Report the time when the packet was received")
parser.add_argument("-P", "--IP", nargs=2, help="Server Port. Connect via TCP To a device instead of reading from StdIn,")
parser.add_argument("-R", "--Raw", nargs=1, help="File to Log Raw Data to")
parser.add_argument("-V", "--Verbose", action="store_true", help="Verbose")

args=parser.parse_args()

#print (args)

Dump_Undecoded = args.Undecoded
Dump_Decoded = args.Decoded
Dump_TimeStamp = args.Time
Print_ACK_NAK  = args.ACK
Verbose = args.Verbose

if args.Explain:
    print(("Dump undecoded: {},  Dump Decoded: {},  Dump ACK/NACK: {}, Dump TimeStamp: {}".format(
        Dump_Undecoded,
        Dump_Decoded,
        Dump_TimeStamp)))



dcol=Dcol(internal=False,default_output_level=0);


#with open ('DCOL.bin','rb') as input_file:
#   new_data = bytearray(input_file.read(255))


#print args.IP
if args.IP == None:
    if Verbose:
        print("Using Standard Input", file=sys.stderr)
    Use_TCP=False
    new_data = bytearray(sys.stdin.buffer.read(1))
else:
    if Verbose:
        print("Using TCP", file=sys.stderr)
    Use_TCP=True
    HOST = args.IP[0]
    PORT = int(args.IP[1])
    Remote_TCP = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    Remote_TCP.connect((HOST, PORT))
    new_data = Remote_TCP.recv(1)

Log_Raw=False

if args.Raw:
    Log_Raw=True
    Raw_File=open(args.Raw[0]+".BIN","wb")

Decoded_Packets=0
UnDecoded_Bytes=0

while (new_data):
    if Log_Raw:
        Raw_File.write(new_data)
    dcol.add_data (data=new_data)
#    new_data = input_file.read(255)
#    if len(dcol.buffer):
#        print str(len(dcol.buffer)) + ' ' + hex(dcol.buffer[len(dcol.buffer)-1])
#        sys.stdout.flush()
    result = dcol.process_data (dump_decoded=False)

    while result != 0 :
#        print(result)
        if result == Got_Undecoded :
            UnDecoded_Bytes+=1
            if Verbose:
                print(f"DCOL Packets Decoded: {Decoded_Packets}  Unknown Bytes:{UnDecoded_Bytes}", file=sys.stderr)
            if Dump_Undecoded :
                print(("Undecoded Data: " +ByteToHex(dcol.undecoded)));

        elif result == Got_Packet :
            Decoded_Packets+=1
            if Verbose:
                print(f"DCOL Packets Decoded: {Decoded_Packets}  Unknown Bytes:{UnDecoded_Bytes}", file=sys.stderr)
            dcol.dump(dump_undecoded=Dump_Undecoded,dump_decoded=Dump_Decoded,dump_timestamp=Dump_TimeStamp);
            sys.stdout.flush()
        elif result == Got_Sub_Packet:
            if dcol.Dump_Levels[dcol.packet_ID] :
                print((dcol.name() + ' ( ' +  hex(dcol.packet_ID) +" ) : "))
                print(" Sub packet of mutiple packet message")
                print("")
                sys.stdout.flush()
        elif result == Missing_Sub_Packet:
            if dcol.Dump_Levels[dcol.packet_ID] :
                print((dcol.name() + ' ( ' +  hex(dcol.packet_ID) +" ) : "))
                print(" Final sub packet of mutiple packet message, missed a sub packet.")
                print("")
                sys.stdout.flush()
        elif result == Got_ACK:
            pass
        elif result == Got_NACK:
            pass
        else :
            print("INTERNAL ERROR: Unknown result", file=sys.stderr)
            print("-1")
            sys.exit();
#        print "processing"
        result = dcol.process_data ()
#        print "processed: " + str(result)
    if Use_TCP:
        new_data = Remote_TCP.recv(1)
    else:
        new_data = sys.stdin.buffer.read(1)


if Use_TCP:
    Remote_TCP.close()

if Log_Raw:
    Raw_File.close()

print(Decoded_Packets)

if Verbose:
    print("Bye", file=sys.stderr)

