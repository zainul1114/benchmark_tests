#!/bin/bash
: '
IOPS Pseudo Code
For (ActiveRange(0:100), optional ActiveRange(Test Operator Choice))
1 Purge the device. (Note: ActiveRange and other Test Parameters are not
applicable to Purge step; any values can be used and none need to be
reported.)
2 Run Workload Independent Preconditioning
2.1 Set and record test conditions:
2.1.1 Device volatile write cache = disabled
2.1.2 OIO/Thread: Test Operator Choice
2.1.3 Thread Count: Test Operator Choice
2.1.4 Data Pattern: Required = Random, Optional = Test Operator
2.2 Run SEQ Workload Independent Preconditioning - Write 2X User Capacity
with 128KiB SEQ writes, writing to the entire ActiveRange without LBA
restrictions.
3 Run Workload Dependent Preconditioning and Test stimulus. Set test
parameters and record for later reporting
3.1 Set and record test conditions:
3.1.1 Device volatile write cache = Disabled
3.1.2 OIO/Thread: Same as in step 2.1 above.
3.1.3 Thread Count: Same as in step 2.1 above.
3.1.4 Data Pattern: Required= Random, Optional = Test Operator Choice.
3.2 Run the following test loop until Steady State is reached, or maximum
of 25 Rounds:
3.2.1 For (R/W Mix % = 100/0, 95/5, 65/35, 50/50, 35/65, 5/95, 0/100)
SSS PTS-Enterprise Version 1.1 SNIA Technical Position 30
3.2.1.1 For (Block Size = 1024KiB, 128KiB, 64KiB, 32KiB, 16KiB,
8KiB, 4KiB, 0.5KiB)
3.2.1.2 Execute RND IO, per (R/W Mix %, Block Size), for 1 minute
3.2.1.2.1 Record Ave IOPS (R/W Mix%, Block Size)
3.2.1.2.2 Use IOPS (R/W Mix% = 0/100, Block Size = 4KiB) to
detect Steady State.
3.2.1.2.3 If Steady State is not reached by Round x=25, then the
Test Operator may either continue running the test
until Steady State is reached, or may stop the test at
Round x. The Measurement Window is defined as Round x-4
to Round x.
3.2.1.3 End “For Block Size” Loop
3.2.2 End “For R/W Mix%” Loop
4 Process and plot the accumulated Rounds data, per report guidelines in 7.3.
End (For ActiveRange)0 loop
Note: It is important to adhere to the nesting of the loops as well as the sequence of R/W Mixes
and Block Sizes.
'

# FIO: Test JOB

function test_cmd()
{
  # Change this variable to the path of the device you want to test
  block_dev=/$mount/$point

  # install dependencies
  sudo apt-get -y update
  sudo apt-get install -y fio

  # full write pass
  sudo fio --name=writefile --size=10G --filesize=10G \
  --filename=$block_dev --bs=1M --nrfiles=1 \
  --direct=1 --sync=0 --randrepeat=0 --rw=write --refill_buffers --end_fsync=1 \
  --iodepth=200 --ioengine=libaio

  # rand read
  sudo fio --time_based --name=benchmark --size=10G --runtime=30 \
  --filename=$block_dev --ioengine=libaio --randrepeat=0 \
  --iodepth=128 --direct=1 --invalidate=1 --verify=0 --verify_fatal=0 \
  --numjobs=4 --rw=randread --blocksize=4k --group_reporting

  # rand write
  sudo fio --time_based --name=benchmark --size=10G --runtime=30 \
  --filename=$block_dev --ioengine=libaio --randrepeat=0 \
  --iodepth=128 --direct=1 --invalidate=1 --verify=0 --verify_fatal=0 \
  --numjobs=4 --rw=randwrite --blocksize=4k --group_reportin
}

function test_fio()
{
  # Random read-write perforamance
  fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75
  
  # Random read
  fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randread
  
  # Random write
  fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randwrite
    
}

function hdparam_test()
{
  # Test using hdparam direct read; This measurement is an indication of how fast the drive can sustain sequential data reads under Linux, without any filesystem overhead.
  sudo hdparm -t /dev/sda2
  
  # Cached Read; This displays the speed of reading directly from the Linux buffer cache without disk access.
  sudo hdparm -T /dev/sda2
}

function dd_test()
{
  # WRITE SPEED
  sync; dd if=/dev/zero of=tempfile bs=1M count=1024; sync
  
  # READ SPEED
  dd if=tempfile of=/dev/null bs=1M count=1024
}

function ssd_iops()
{
  # For ActiveRange 0:100
    # purge
    # Run Workload Independent Pre-conditioning
      #**********************************************************************************************************#
      # Set and record test conditions
      # Disable device volatile write cache, OIO/Threads, Thread_count, Data pattern: random,operator
      # Run sequential WIPC with: 2X User capacity @128KiB SEQ Write, writing to entire LBA without restrictions.
      #**********************************************************************************************************#
      
      # Test Conditions
      # Disable volatile cache using direct=1, non-buffered io
      DIRECT=1
      
      # thread_count
      NUMJOBS=4
      
      # Data Pattern: random, operator
      RW=write  # Sequential read write
      IOENGINE=libaio
            
      # Capacity 2X, BlockSize=128KiB, sequential write file_service_type=sequential
      size=$((2*430)) #$((2*$mb_memory))m # ?, can also be represented in %.
      bs=128k
      #file_service_type=sequential
      
      # READ/WRITE Mix % : Eg. --rwmixread=90 i.e 90% Read, 10% Write
      # RWMIXREAD=90
      
           
      # RUNNING WIPC
      #sudo fio --name=WIPC --direct=${DIRECT} --numjobs=${NUMJOBS} --size=${size} --bs=${bs} --rw=${RW} --ioengine=${IOENGINE} > WIPC_Write.txt
      
           
    # Run Workload Dependent Pre-conditioning and Test Stimulus
      #**********************************************************************************************************#
      # Set and record test conditions
      # Disable device volatile write cache, OIO/Threads, Thread_count, Data pattern: random,operator (same as previous step)
      
      # Run WDPC until steady state is achieved/ MAX 25 rounds
        # For (R/W Mix % = 100/0, 95/5, 65/35, 50/50, 35/65, 5/95, 0/100)
          # For (Block Size = 1024KiB, 128KiB, 64KiB, 32KiB, 16KiB, 8KiB, 4KiB, 0.5KiB)
            # Execute RND IO, per (R/W Mix %, Block Size), for 1 minute 
              # Record Ave IOPS (R/W Mix%, Block Size)
              # Use IOPS (R/W Mix% = 0/100, Block Size = 4KiB) to detect Steady State. 
              # If Steady State is not reached by Round x=25, then the Test Operator may either continue running the test until Steady State is reached, or may stop the test at Round x. The Measurement Window is defined as Round x-4 to Round x.
      #**********************************************************************************************************#
      for i in `seq 1 5`
      do
      for rwmix in 100 95 65 50 35 5 0
      do
        for blk_size in 1024k 128k 64k 32k 16k 8k 4k 0.5k
        do
        sudo fio --name=WDPC --bs=${blk_size} --rwmixwrite=${rwmix} --direct=${DIRECT} --rw=randrw --runtime=1s > WDPC_${rwmix}_${blk_size}_iter${i}.txt
        done
      done
      done
      
    # Process and Plot the accumulated rounds data 
  
}
set -x

ssd_iops
