{{
  Simple iRobot Create controller

  Version: 0.0.2
}}

CON     ''System constant definitions
        
        'Standard clock mode * crystal frequency = 80 MHz
        _clkmode = xtal1 + pll16x
        _xinfreq = 5_000_000

        'IO definitions
        DEBUG_RX  = 31
        DEBUG_TX  = 30
        CREATE_RX = 27
        CREATE_TX = 26
        LED       = 15

        'Buffer sizes
        IR_BUFFER_SIZE = 64
        ODOMETRY_BUFFER_SIZE = 16

        'Character constants
        CR      = $0D
        LF      = $0A
        SP      = $20

OBJ     ''Object definitions
  
  Debug       : "FullDuplexSerial"
  Create      : "FullDuplexSerial"

VAR     ''System variable definitions

  long FwdStack[128]
  long ParseStack[128]

VAR     ''Sensor variable definitions     

  long OdoBuffStart
  long OdoBuffEnd
  long IRBuffStart
  long IRBuffEnd

  byte BumpDrop
  byte CliffWall
  byte Overcurrent
  byte IRRaw
  byte Buttons
  byte Charger
  byte Mode
  byte StreamSize
  byte Digital
  word Analog
  word Song
  word Battery[5]
  word Distance[5]
  long LastDrive
  long LastDirect
  long Odometry[ODOMETRY_BUFFER_SIZE]
  byte IRData[IR_BUFFER_SIZE]  
  
PUB Main | i

  dira[LED]~~
  outa[LED]~~

  Debug.Start(DEBUG_RX, DEBUG_TX, %0000, 57_600)
  Debug.Str(string("Init",CR,LF))

  'Start serial to Create, wait for it to start, and discard startup output 
  Create.Start(CREATE_RX, CREATE_TX, %0000, 57_600)
  waitcnt(clkfreq*2 + cnt)
  Create.RxFlush
  Debug.Str(string("Create Post-Boot",CR,LF))   

  'Execute startup sequence
  SendCmd(@StartupSeq)
  Debug.Str(string("Startup Finished",CR,LF))

  'Forward incoming commands in new cog
  Debug.Str(string("Forwarding commands to create",CR,LF))
  cognew(SerForward, @FwdStack) 

  'Parse sensor stream in new cog
  Debug.Str(string("Parsing sensor stream",CR,LF))
  cognew(StreamParser, @ParseStack) 

  'Print battery values
  Debug.Tx(CR)
  Debug.Tx(LF)
  repeat
    if IRBuffStart < IRBuffEnd
      Debug.Tx(IRData[IRBuffStart++ // IR_BUFFER_SIZE])
       

PUB SerForward

  repeat
    Create.Tx(Debug.Rx)

PUB StreamParser | len, id, wallAcc, irByte, odoInc

  repeat
    repeat while Create.Rx <> 19
    len := Create.Rx
    repeat while len > 0
      id := Create.Rx
      len -= 1
      
      if lookdown(id: 6,0,1,7)
        BumpDrop := Create.Rx
        len -= 1

      wallAcc := 0
      if lookdown(id: 6,0,1,8)
        wallAcc |= Create.Rx
        len -= 1
      if lookdown(id: 6,0,1,9)
        wallAcc |= Create.Rx << 1
        len -= 1
      if lookdown(id: 6,0,1,10)
        wallAcc |= Create.Rx << 2
        len -= 1
      if lookdown(id: 6,0,1,11)
        wallAcc |= Create.Rx << 3
        len -= 1
      if lookdown(id: 6,0,1,12)
        wallAcc |= Create.Rx << 4
        len -= 1
      if lookdown(id: 6,0,1,13)
        wallAcc |= Create.Rx << 5
        len -= 1
      CliffWall := wallAcc

      if lookdown(id: 6,0,1,14)
        Overcurrent := Create.Rx
        len -= 1

      if lookdown(id: 6,0,1,15)
        Create.Rx
        len -= 1
      if lookdown(id: 6,0,1,16)
        Create.Rx
        len -= 1

      if lookdown(id: 6,0,2,17)
        irByte := Create.Rx
        if irByte < 128 and irByte <> IRRaw
          IRData[IRBuffEnd++ // IR_BUFFER_SIZE] := irByte
        IRRaw := irByte  
        len -= 1

      if lookdown(id: 6,0,2,18)
        Buttons := Create.Rx
        len -= 1

      odoInc := false
      if lookdown(id: 6,0,2,19)
        Odometry.word[OdoBuffEnd*2 // ODOMETRY_BUFFER_SIZE] := Create.Rx << 8 | Create.Rx
        odoInc := true
        len -= 2
      if lookdown(id: 6,0,2,20)
        Odometry.word[(OdoBuffEnd*2 + 1) // ODOMETRY_BUFFER_SIZE] := Create.Rx << 8 | Create.Rx
        odoInc := true
        len -= 2
      if odoInc
        OdoBuffEnd++

      if lookdown(id: 6,0,3,21)
        Battery.byte[0] := Create.Rx
        len -= 1

      if lookdown(id: 6,0,3,22)
        Battery.word[1] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,0,3,23)
        Battery.word[2] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,0,3,24)
        Battery.byte[1] := Create.Rx
        len -= 1

      if lookdown(id: 6,0,3,25)
        Battery.word[3] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,0,3,26)
        Battery.word[4] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,27)
        Distance.word[0] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,28)
        Distance.word[1] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,29)
        Distance.word[2] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,30)
        Distance.word[3] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,31)
        Distance.word[4] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,32)
        Digital := Create.Rx
        len -= 1

      if lookdown(id: 6,4,33)
        Analog := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,4,34)
        Charger := Create.Rx
        len -= 1

      if lookdown(id: 6,5,35)
        Mode := Create.Rx
        len -= 1

      if lookdown(id: 6,5,36)
        Song.byte[0] := Create.Rx
        len -= 1

      if lookdown(id: 6,5,37)
        Song.byte[1] := Create.Rx
        len -= 1

      if lookdown(id: 6,5,38)
        StreamSize := Create.Rx
        len -= 1

      if lookdown(id: 6,5,39)
        LastDrive.word[0] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,5,40)
        LastDrive.word[1] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,5,41)
        LastDirect.word[0] := Create.Rx << 8 | Create.Rx
        len -= 2

      if lookdown(id: 6,5,42)
        LastDirect.word[1] := Create.Rx << 8 | Create.Rx
        len -= 2  
 
PRI SendCmd(cmdPtr)

  repeat byte[cmdPtr++]
    Create.Tx(byte[cmdPtr++])
      
DAT     ''Startup command sequence

  StartupSeq  byte 4            'Length of sequence, in bytes
              byte 128          'Start OI, enter passive mode
              byte 148, 1, 6    'Start streaming all sensor data, packet 6
  