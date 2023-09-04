#DCOL_Decls

Bit15 = 1 << 15;
Bit14 = 1 << 14;
Bit13 = 1 << 13;
Bit12 = 1 << 12;
Bit11 = 1 << 11;
Bit10 = 1 << 10;
Bit9  = 1 << 9;
Bit8  = 1 << 8;
Bit7  = 1 << 7;
Bit6  = 1 << 6;
Bit5  = 1 << 5;
Bit4  = 1 << 4;
Bit3  = 1 << 3;
Bit2  = 1 << 2;
Bit1  = 1 << 1;
Bit0  = 1;


# TDump_Level
Dump_None=0
Dump_ID=1
Dump_Summary=2
Dump_Full=3
Dump_Verbose=4


STX = 2;
ETX = 3;
ENQ = 0x5;
ACK = 0x06;
NACK = 0x15;



TrimComm_Start           = STX;
TrimComm_End             = ETX;

# Locations are zero based
TrimComm_First_Checksum_Location = 1;  #{First location that is included in the checksum}
TrimComm_Checksum_Location = 4;
TrimComm_End_Location    = 5; #{# Within 'header'}
TrimComm_First_Data_Location = 4;
TrimComm_Status_Byte_Location = 1;
Trimcomm_Type_Location = 2;
TrimComm_Length_Location = 3;
TrimComm_Min_Size      = 6;


#HH command numbers}
GETSERIAL_TrimComm_Command = 0x06; #Get Receiver & Antenna Serial Numbers}
RETSERIAL_TrimComm_Command = 0x07; #Receiver & Antenna Serial Numbers}
GETSTAT1_TrimComm_Command  = 0x08;
RECSTAT1_TrimComm_Command  = 0x09;

GETTIME_TrimComm_Command   = 0x14;
RETTIME_TrimComm_Command   = 0x15;

SETANT_TrimComm_Command = 0x1B

GENOUT_TrimComm_Command    = 0x40; #GSOF}
SETCOMMS_TrimComm_Command  = 0x48; #SETCOMMS}
COMMOUT_TrimComm_Command   = 0x49;
SetIdle_TrimComm_Command   = 0x4F;

AppFile_TrimComm_Command   = 0x64;

BreakRET_TrimComm_Command  = 0x6E;
BreakReq_TrimComm_Command  = 0x6F;

CMR_Type_TrimComm_Command  = 0x93;
CMR_PLUS_TrimComm_Command  = 0x94;

CMRW_TrimComm_Command      = 0x98;


TSV_System_Names = (
   'GPS',
   'SBAS (WAAS, EGNOS, MSAS etc)',
   'GLONASS',
   'Galileo',
   'QZSS',
   'Compass (pre-ICD SV numbering)',
   'OmniStar',
   'Compass (ICD SV numbering)',
   'Terralite XPS'
   )

TPort_Names = (
   'Serial 1',
   'Serial 2',
   'Serial 3',
   'Radio',
   'Event Marker',
   '1PPS',
   'External Freq',
   'Reserved 7',
   'Reserved 8',
   'Reserved 9',
   'Reserved 10',
   'Reserved 11',
   'Reserved 12',
   'CAN0',
   'CAN1',
   'USB',
   'BlueTooth 1',
   'BlueTooth 2',
   'BlueTooth 3',
   'IP 1',
   'IP 2',
   'IP 3',
   'IP 4',
   'IP 5',
   'IP 6',
   'IP 7',
   'IP 8',
   'IP 9',
   'IP 10',
   'NTRIP Client 1',
   'NTRIP Server 1',
   'NTRIP Caster 1',
   'NTRIP Caster 2',
   'NTRIP Caster 3',
   'Beacon',
   'Reserved 36',
   'NTRIP Client 2',
   'NTRIP Client 3',
   'NTRIP Server 2',
   'NTRIP Server 3',
   'Cell',
   'MSS-Band',
   'USB-to-Serial')

class Trimcomm_Command_Names:
    def __init__ (self):
        self.Command_Names={};

        for B in range(0,256) :
           self.Command_Names[B] ='Unknown packet ID: ' + hex(B);

        self.Command_Names[GETTIME_TrimComm_Command] = 'GetTime' #4000 Manual
        self.Command_Names[RETTIME_TrimComm_Command] = 'RetTime' #4000 Manual
        self.Command_Names[SETANT_TrimComm_Command]  = 'SetAnt'; #4000 Manual
        self.Command_Names[GETSERIAL_TrimComm_Command] = 'GetSerial'; #BD970 manual
        self.Command_Names[RETSERIAL_TrimComm_Command] = 'RetSerial'; #BD970 manual
        self.Command_Names[GETSTAT1_TrimComm_Command]  = 'GetStat1';  #4000 RS-232 Manual
        self.Command_Names[RECSTAT1_TrimComm_Command]  = 'RecStat1';  #4000 RS-232 Manual
        self.Command_Names[SETCOMMS_TrimComm_Command]  = 'SetComms';  #4000 RS-232 Manual
        self.Command_Names[COMMOUT_TrimComm_Command]  = 'CommOut'
        self.Command_Names[SetIdle_TrimComm_Command]  = 'SetIdle'
        self.Command_Names[BreakRET_TrimComm_Command]  = 'Break Ret'
        self.Command_Names[BreakReq_TrimComm_Command]  = 'Break Req'
        self.Command_Names[GENOUT_TrimComm_Command]    = 'GSOF'
        self.Command_Names[CMR_Type_TrimComm_Command] = 'CMR'
        self.Command_Names[CMR_PLUS_TrimComm_Command] = 'CMR+'
        self.Command_Names[CMRW_TrimComm_Command] = 'GLONASS CMR'
        

    def name (self,packet_ID):
        return self.Command_Names[packet_ID]

    def add_name (self,packet_ID,name):
        self.Command_Names[packet_ID]=name;


TSV_System_Names = (
   'GPS',
   'SBAS (WAAS, EGNOS, MSAS etc)',
   'GLONASS',
   'Galileo',
   'QZSS',
   'Compass (pre-ICD SV numbering)',
   'OmniStar',
   'Compass (ICD SV numbering)',
   'Terralite XPS'
   )



Trimcomm_Names = Trimcomm_Command_Names()

Zero_Length_Commands = set([
    GETSERIAL_TrimComm_Command,
    GETSTAT1_TrimComm_Command,
    BreakReq_TrimComm_Command,
    ]);

#Request Commands we don't display the status byte for

Non_Reply_Commands = set ([
    GETSERIAL_TrimComm_Command,
    GETSTAT1_TrimComm_Command,
    SETCOMMS_TrimComm_Command,
    BreakReq_TrimComm_Command,
    CMR_Type_TrimComm_Command,
    CMR_PLUS_TrimComm_Command
    ])
    
    
TMotion_Names= (
   'Unknown 0',
   'Static',
   'Kinematic',
   'Unknown 3')


try:
   from DCOL_Internal import *
except:
#   import sys
#   sys.stderr.write("Note: Trimble Internal Not available")
   pass

