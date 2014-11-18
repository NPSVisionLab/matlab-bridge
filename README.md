MatlabBridge
============

# EasyCV (CVAC) bridge to Matlab services

This is a Python service that uses Google Protocol Buffers (protobuf)
to transfer the EasyCV data structure into and out of Matlab.  The
service is configured through the config.service file.  Configuration
includes the name of the service, its TCP/IP port, the location of the
Matlab executable, the Matlab file that gets invoked, and a temp
directory for message exchange.

## Examples:

## Configuration File
Services are configured as in this example:
config.service.matlab_bridge

### Kalman Tracker
This sample requires availability of the Matlab Vision Toolbox.  You
will be able to run the Kalman filter tracking on a simple video
sequence of a ball rolling across the field of view.

sample client code: track_kalman.py

sample Matlab code: kalman_tracker.m


### Matlab/Protocol buffer stub code for detector training

training_sample.m

### Matlab/Protocol buffer stub code for detecting

detection_sample.m


## Installation

This project ties in with [EasyCV](http://npsvisionlab.github.io/CVAC/).
Just clone this repository into EasyCV/algorithms/matlab-bridge and
create a file EasyCV/algorithms/UserCMakeLists.txt
with the following contents:

```
IF (BUILD_WITH_MATLABBRIDGE)
  ADD_SUBDIRECTORY(matlab-bridge)
ENDIF ()
```

### if you want to rebuild the protobuffer files (this is not necessary)

Follow the instructions for
[building the protobuf-matlab compiler](https://code.google.com/p/protobuf-matlab/source/browse/README.txt),
but add the following include directives into
protobuf/src/google/protobuf/message.cc before building:
```C++
#include <string>
#include <iostream>
```
