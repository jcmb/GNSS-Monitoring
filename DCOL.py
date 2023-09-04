# Run Decode_Decode.py
"""
DCOL:

This object provides the core decoding and dispatch of DCOL packets.

It does support the 2 byte length packets, if they are known to the system.

To add a new packet decoder you need to

1: Add a line in add_handlers to call the new decoder for that packet type.
2: Add an import at the bottom of the file for the file that has the decoder
3: If the decoder is an internal one then make one in internal_stub which just contains a pass

"""

from binascii import hexlify
from DCOL_Decls import *

from ENUM import enum
from array import array
from datetime import datetime
from pprint import pprint

import sys


Need_More=0
Got_ACK=1
Got_NACK=2
Got_Undecoded=3 # This is not really an undecoded packet but bytes that are not part of a packet
Got_Packet=4
Got_Sub_Packet=5
Missing_Sub_Packet=6
Invalid_Decode=255


# ByteToHex From http://code.activestate.com/recipes/510399-byte-to-hex-and-hex-to-byte-string-conversion/

def ByteToHex( byteStr ):
    """
    Convert a byte string to it's hex string representation e.g. for output.
    """

    hex = []
    for aChar in byteStr:
        hex.append( "%02X " % aChar )

    return ''.join( hex ).strip()




class Dcol:
    def __init__ (self,internal,default_output_level):
        self.undecoded=bytearray()
        self.buffer=bytearray()
        self.internal=internal
        self.default_output_level=default_output_level
        self.last_packet_valid=False
        self.packet_ID=-1
        self.Handlers={}
        self.Status_Byte=0
        self.Long_Packet=False
        self.Traffic=False
        self.Looking_For_Traffic=False
        self.Packet_Data_Length = 0


        for B in range(0,256) :
           self.Handlers[B]=None

        self.add_handlers(internal)
        self.Dump_Levels=array("B");

        for i in range (0,255):
            self.Dump_Levels.append(default_output_level)


    def Set_Traffic (self,To_Traffic):
      self.Traffic=To_Traffic
      self.Looking_For_Traffic=To_Traffic

    def add_data (self,data):
    # Add more received data into the system. Adding data does not mean that we will try and decode it.
        self.buffer+=data
#        print len(self.buffer)
#       print hexlify(self.buffer)



    def process_data (self, dump_decoded=False):
    # Process the data in the buffer, will return
    # Got_ACK
    # Got_NACK
    # Got_Undecoded. Got data that is known to be invalid
    # Got_Packet. Got a valid packet. Will be output to STDOUT if dump_decoded=True
    # Need More. Have the start of a DCOL packet but have not got enough data to finish it

        """
        Note that the Length is not protected by a checksum so it is possible when there is invalid data that the decoder will get an invalid length
        this will cause the decoder to stall until length bytes have been received. Since the system will be waiting for that full packet.

        With the new 2 byte packet support this could take upto 64K of data. Once the amount of data comes in the system will clear the backlog,
        if called correctly.

        You MUST continue to call process_data until it returns Need_More.

        The decoder is a reasonably standard decoder, it is designed to be simple not super fast

        """
#        print len (self.buffer)
        self.packet_ID = 0;

        if len (self.buffer) > 0 :
            self.undecoded=bytearray();
            if self.Looking_For_Traffic: #This is the V2 traffic format
#               print "Looking for Traffic"
               if (len(self.buffer) <= 5) :
                  return Need_More;
               else:
                  if  (self.buffer[0] == 0xaa) and (self.buffer[1] == 0x02) and ((self.buffer[3] == 0x00) or (self.buffer[3] == 0x01)) : #The traffic always starts with a 0 or 1, if it isn't just skip the traffic
                     del self.buffer[0:5]
                     self.Looking_For_Traffic = False
                     return Need_More
                  else :
#                     print "Not a traffic stream"
                     self.Looking_For_Traffic = False

            if self.buffer[0] != TrimComm_Start :
                if self.buffer[0] == ACK :
#                    print "ACK"
                    del self.buffer[0];
                    self.Looking_For_Traffic = self.Traffic
                    return Got_ACK
                else:
                    if self.buffer[0] == NACK :
#                        print "NACK"
                        del self.buffer[0];
                        self.Looking_For_Traffic = self.Traffic
                        return Got_NACK
                    else :
#                        print "Did not get a STX: " + str(len(self.buffer)-1 if len(self.buffer) >1 else 1)
                        for i  in range (0,len(self.buffer)):
#                            print "in Did not get a STX: " + str(i)
                            if (self.buffer[0] != TrimComm_Start) and  (self.buffer[0] != ACK) and (self.buffer[0] != NACK) :
                                self.undecoded.append(self.buffer[0]);
                                del self.buffer[0];
                            else:
                                break;
 #                       print "undecoded: " + hexlify(self.undecoded);
                        return Got_Undecoded
            else :
#                print "Did get a 2"
                if len (self.buffer) >= TrimComm_Min_Size :
#                    print "Buffer: " + ByteToHex(self.buffer);

                    packet_length=self.buffer[TrimComm_Length_Location];
                    self.packet_ID = self.buffer[Trimcomm_Type_Location];

                    if (self.packet_ID == 0x95) or (self.packet_ID == 0x96) or (self.packet_ID == 0xC2): # The Horrible 2 byte packets.
# Two byte length packets
                       """
                       There are some packets that have a 2 byte length instead of using multi packets (which are also horrid)
                       When one of the packet_ID that is a known 2 byte packet is detected the packet_length, the packet length is
                       computed using the 2 bytes of length.

                       Long_Packet_Adjustment 0 unless it is a long packet then it is 1

                       Long_Packet_Adjustment is used to avoid having if statements, it is used to allow for the fact that everything after
                       the length byte is offset by 1 Byte.  Normally needs to be used in anything accessing the buffer.

                       Next time I add another 2 byte command I need to make it defined set since this is really tacky

                       """
                       packet_length=packet_length*256
                       packet_length+=self.buffer[TrimComm_Length_Location+1]
#                       print "Long Packet:: id: {:X} Length: {:X} Buffer: {:X}".format(self.packet_ID,packet_length,len(self.buffer))
                       self.Long_Packet=True
                       Long_Packet_Adjustment=1
                    else :
#                       print "Normal Packet:: id: {:X} Length: {:X} Buffer: {:X}".format(self.packet_ID,packet_length,len(self.buffer))
                       self.Long_Packet=False
                       Long_Packet_Adjustment=0


                    if len (self.buffer) >= (packet_length + TrimComm_Min_Size+Long_Packet_Adjustment) :
#                        print "Have a STX with enough data in the buffer for the packet"
                        if (self.buffer[packet_length + TrimComm_End_Location+Long_Packet_Adjustment] == TrimComm_End) :
#                            print "have valid end of packet"
                            Checksum = 0;
#                            print TrimComm_First_Checksum_Location,packet_length + TrimComm_Checksum_Location;
                            for i  in range (TrimComm_First_Checksum_Location,packet_length + TrimComm_Checksum_Location+Long_Packet_Adjustment):
                                 Checksum += self.buffer[i];
#                                 print "i: " + str(i) + " " + hex(self.buffer[i]) + " " + str(Checksum);

                            Checksum = Checksum % 256
#                            print "Checksum: " + hex(Checksum)

                            Checksum_In_Packet = self.buffer[packet_length + TrimComm_Checksum_Location+Long_Packet_Adjustment];
#                            print "Expected: " + hex(Checksum_In_Packet)

                            if (Checksum == Checksum_In_Packet) :
#                                print "Did get a valid TrimComm packet"
#                                 Decode_Status_Byte;
                                self.packet_ID = self.buffer[Trimcomm_Type_Location];
                                self.Status_Byte=self.buffer[TrimComm_Status_Byte_Location]
                                self.last_packet_valid = True;
                                self.packet = self.buffer[0:packet_length + TrimComm_End_Location+1+Long_Packet_Adjustment];
                                self.Packet_Data_Length=packet_length +Long_Packet_Adjustment
                                if (packet_length != 0) :
                                    self.data = self.buffer [TrimComm_First_Data_Location +Long_Packet_Adjustment : TrimComm_First_Data_Location + packet_length]
                                else :
                                    self.data = bytearray("");

                                del self.buffer[0:packet_length + TrimComm_End_Location+1+Long_Packet_Adjustment]

                                if dump_decoded :
                                    print(("Packet Data: " + ByteToHex (self.packet)))

                                if self.Handlers[self.packet_ID] :
#                                    print "have a handler for packet: " + hex (self.packet_ID)
#                                    pprint(self.packet)
 #                                   pprint(self.data)
 #                                   print ("packet: {} {}".format(str(len(self.packet)), hexlify(self.packet)))
                                    Result = self.Handlers[self.packet_ID].decode(self.data,self.internal);
                                    self.Looking_For_Traffic = self.Traffic
                                    return Result;
                                else :
#                                    print "dont have a handler for packet: " + hex (self.packet_ID)
                                    self.Looking_For_Traffic = self.Traffic
                                    return Got_Packet

                            else:
#                                print "Did get an invalid TrimComm checksum"
#                               Scan for the next STX character since this packet is invalid
                                self.undecoded.append(self.buffer[0]);
                                del self.buffer[0];
                                for i  in range (0,len(self.buffer)):
#                                    print "in looking a STX: " + str(i)
                                    if (self.buffer[0] != TrimComm_Start) : # and (self.buffer[0] != ACK) and (self.buffer[0] != NACK) :
                                        self.undecoded.append(self.buffer[0]);
                                        del self.buffer[0];
                                    else:
                                        break;
                                return Got_Undecoded
                        else:
#                           Scan for the next STX character since this packet is invalid
                            self.undecoded.append(self.buffer[0]);
                            del self.buffer[0];
                            for i  in range (0,len(self.buffer)):
#                                print "in Did not get a STX: " + str(i)
                                if (self.buffer[0] != TrimComm_Start) : # and (self.buffer[0] != ACK) and (self.buffer[0] != NACK) :
                                    self.undecoded.append(self.buffer[0]);
                                    del self.buffer[0];
                                else:
                                    break;
#                            print "Did not get a valid TrimComm End"
                            return Got_Undecoded

                    else:
#                        print "Have a STX with not enough data in the buffer for the packet"
                        return Need_More;

                else :
#                    print "Have a STX with not enough data in the buffer for a packet"
                    return Need_More;
        else :
            return Need_More;

    def name (self):
        return Trimcomm_Names.name(self.packet_ID)

    def _add_Handler(self,packet_ID,handler):
        self.Handlers[packet_ID]=handler;


    def zero_length_packet(self):
        pass

    def add_handlers (self,internal):
        try:
            self._add_Handler(SETANT_TrimComm_Command,SetAnt.SetAnt());
        except:
            pass

        try:
            self._add_Handler(GETTIME_TrimComm_Command, GetTime.GetTime()) #4000 Manual
        except:
            pass

        try:
            self._add_Handler(RETTIME_TrimComm_Command, RetTime.RetTime()) #4000 Manual
        except:
            pass


        try:
            self._add_Handler(RECSTAT1_TrimComm_Command,RetStat1.RetStat1());
        except:
            pass

        try:
            self._add_Handler(RETSERIAL_TrimComm_Command,RetSerial.RetSerial());
        except:
            pass

        try:
            self._add_Handler(SETCOMMS_TrimComm_Command,SetComms.SetComms());
        except:
            pass

        try:
            self._add_Handler(GENOUT_TrimComm_Command,GSOF.GSOF());
        except:
            pass

        try:
            self._add_Handler(CMR_Type_TrimComm_Command,CMR.CMR());
        except:
            pass

        try:
            self._add_Handler(CMR_PLUS_TrimComm_Command,CMRPlus.CMRPlus());
        except:
            pass

        try:
            self._add_Handler(BreakRET_TrimComm_Command,RetBreak.RetBreak());
        except:
            pass

        try:
            self._add_Handler(COMMOUT_TrimComm_Command,CommOut.CommOut());
        except:
            pass

        try:
            self._add_Handler(SetIdle_TrimComm_Command,SetIdle.SetIdle())
        except:
            pass

    #        self._add_Handler(AppFile_TrimComm_Command,AppFile.AppFile())
        try:
            self._add_Handler(CMRW_TrimComm_Command,CMRGlonass.CMRGlonass())
        except:
            pass


        if internal : # If you are doing it internal we assume you have all the files

            self._add_Handler(Station_TrimComm_Command,Station.Station());
            self._add_Handler(RTKSTAT_TrimComm_Command,RTKStat.RTKStat());
            self._add_Handler(RETRTKSTAT_TrimComm_Command,RetRTKStat.RetRTKStat());
            self._add_Handler(OmniStar_TrimComm_Command,OmniSTAR.OmniSTAR());
            self._add_Handler(Funnel_TrimComm_Command,Funnel.Funnel(internal));
            self._add_Handler(Radio_Pipe_TrimComm_Command,RadioPipe.RadioPipe());
            self._add_Handler(Get_Base_TrimComm_Command,GetBase.GetBase());
            self._add_Handler(Ret_Base_TrimComm_Command,RetBase.RetBase());
            self._add_Handler(GETOPT_TrimComm_Command,GetOpt.GetOpt());
            self._add_Handler(RETOPT_TrimComm_Command,RetOpt.RetOpt());
            self._add_Handler(STARTSURV_TrimComm_Command,StartSurvey.StartSurvey());
            self._add_Handler(Ethernet_CFG_TrimComm_Command,Ethernet.Ethernet());
            self._add_Handler(Survey_Stat_TrimComm_Command,SurveyStat.SurveyStat());
            self._add_Handler(GET_CHALLENGE_RESPONSE_TrimComm_Command,Login.Login());
            self._add_Handler(Wifi_TrimComm_Command,WiFi.WiFi());
            self._add_Handler(SBAS_Control_TrimComm_Command,SBAS.SBAS());
            self._add_Handler(GETSVDATA_TrimComm_Command,GetSVData.GetSVData())
            self._add_Handler(RETSVDATA_TrimComm_Command,RetSVData.RetSVData())
            self._add_Handler(RTKCtrl_TrimComm_Command,RTKCtrl.RTKCtrl())
            self._add_Handler(KNEX_TrimComm_Command,KNEX.KNEX())
            self._add_Handler(AppFile_Get_App_TrimComm_Command,ReqAppFile.ReqAppFile())




    def dump (self,dump_undecoded=False,dump_status=False,dump_decoded=False,dump_timestamp=False):
#        print("dump")
#        print(self.Dump_Levels[self.packet_ID])
        if self.Dump_Levels[self.packet_ID] :
            if dump_timestamp :
               print((datetime.now()))
            print((self.name() + ' ( ' +  hex(self.packet_ID) +" ) " + " Length " + str(len(self.packet))+": "))

            if dump_status:
                if (self.Dump_Levels[self.packet_ID] > Dump_ID) and (not (self.packet_ID in Non_Reply_Commands)) :
                    print((" Status Byte: :{:02X} ".format (
                        self.Status_Byte
                        )))
                    print(("  Low Battery: {}  Low Memory: {}  Roving: {}".format (
                        (self.Status_Byte & Bit1 != 0),
                        (self.Status_Byte & Bit0 != 0),
                        (self.Status_Byte & Bit3 != 0)
                        )))

                    print(("  Synced: {}  Inited: {}  Inited: {}".format (
                        (self.Status_Byte & Bit6 != 0),
                        (self.Status_Byte & Bit5 != 0),
                        (self.Status_Byte & Bit7 != 0)
                        )))
                    print("")


            if self.packet_ID in Zero_Length_Commands :
                if dump_decoded :
                    print((" Packet Data: " + ByteToHex (self.packet)))
                print(" No Extra Information in Command, as expected")
                print("")
            else:
                if self.Handlers[self.packet_ID] :
    #                print "dump have a handler for packet: " + hex (self.packet_ID)
                    if dump_decoded :
                        print((" Packet Data: " + ByteToHex (self.packet)))
                    self.Handlers[self.packet_ID].dump(self.Dump_Levels[self.packet_ID]);

                    print("")
                else :
                    print((" Dont have a decoder for packet: " + hex (self.packet_ID) + " Length " + str(len(self.packet))))
                    if dump_undecoded :
                        print((" Packet Data: " + ByteToHex (self.packet)))
                    print("")


verbose=False

try:
    import RetStat1
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetStat1\n")

try:
    import RetSerial
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetSerial\n")

try:
    import RTKStat
except:
    if verbose: sys.stderr.write("INFO: Failed to load RTKStat\n")

try:
    import RetRTKStat
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetRTKStat\n")

try:
    import OmniSTAR
except:
    if verbose: sys.stderr.write("INFO: Failed to load OmniSTAR\n")

try:
    import SetComms
except:
    if verbose: sys.stderr.write("INFO: Failed to load SetComms\n")

try:
    import Funnel;
except:
    if verbose: sys.stderr.write("INFO: Failed to load Funnel\n")

try:
    import RadioPipe
except:
    if verbose: sys.stderr.write("INFO: Failed to load RadioPipe\n")

try:
    import GSOF
except:
    if verbose: sys.stderr.write("INFO: Failed to load GSOF\n")

try:
    import CMR
except:
    if verbose: sys.stderr.write("INFO: Failed to load CMR\n")

try:
    import CMRPlus
except:
    if verbose: sys.stderr.write("INFO: Failed to load CMRPlus\n")

try:
    import GetBase
except:
    if verbose: sys.stderr.write("INFO: Failed to load GetBase\n")

try:
    import RetBase
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetBase\n")

try:
    import RetOpt
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetOpt\n")

try:
    import RetBreak
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetBreak\n")

try:
    import GetOpt
except:
    if verbose: sys.stderr.write("INFO: Failed to load GeTOpt\n")

try:
    import SurveyStat
except:
    if verbose: sys.stderr.write("INFO: Failed to load SurveyStat\n")

try:
    import Login
except:
    if verbose: sys.stderr.write("INFO: Failed to load Login\n")

try:
    import Station
except:
    if verbose: sys.stderr.write("INFO: Failed to load Station\n")

try:
    import SetAnt
except:
    if verbose: sys.stderr.write("INFO: Failed to load SetAnt\n")

try:
    import GetTime
except:
    if verbose: sys.stderr.write("INFO: Failed to load GetTime\n")

try:
    import RetTime
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetTime\n")

try:
    import StartSurvey
except:
    if verbose: sys.stderr.write("INFO: Failed to load StartSurvey\n")

try:
    import CommOut
except:
    if verbose: sys.stderr.write("INFO: Failed to load CommOut\n")

try:
    import Ethernet
except:
    if verbose: sys.stderr.write("INFO: Failed to load Ethernet\n")

try:
    import WiFi
except:
    if verbose: sys.stderr.write("INFO: Failed to load WiFi\n")

try:
    import SetIdle
except:
    if verbose: sys.stderr.write("INFO: Failed to load SetIdle\n")

try:
    import SBAS
except:
    if verbose: sys.stderr.write("INFO: Failed to load SBAS\n")

try:
    import CMRGlonass
except:
    if verbose: sys.stderr.write("INFO: Failed to load CMRGlonass\n")

try:
    import GetSVData
except:
    if verbose: sys.stderr.write("INFO: Failed to load GetSVData\n")

try:
    import RetSVData
except:
    if verbose: sys.stderr.write("INFO: Failed to load RetSVData\n")

try:
    import RTKCtrl
except:
    if verbose: sys.stderr.write("INFO: Failed to load RTKCtrl\n")

try:
    import KNEX
except:
    if verbose: sys.stderr.write("INFO: Failed to load KNEX\n")

try:
    import ReqAppFile
except:
    if verbose: sys.stderr.write("INFO: Failed to load ReqAppFile\n")

    #import AppFile
