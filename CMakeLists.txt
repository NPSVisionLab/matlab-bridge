# If protoc doesn't exist, just copy the pre-built language bindings
# from the source directory, to the build directory.
# Else, build them with protoc
find_package(Protobuf REQUIRED)
include( protobuf )

SET( MATLAB_BRIDGE_PY_SOURCE_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/MatlabBridge.py 
  ${CMAKE_CURRENT_SOURCE_DIR}/__init__.py )

SET( MATLAB_BRIDGE_M_SOURCE_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/kalman_tracker.m 
  ${CMAKE_CURRENT_SOURCE_DIR}/detection_sample.m 
  ${CMAKE_CURRENT_SOURCE_DIR}/training_sample.m 
  )

OPTION(COMPILE_PROTOBUF "Recompile Protobuf Files" OFF)
IF (NOT COMPILE_PROTOBUF)
  MESSAGE( STATUS "Will use pre-built language bindings.")
  FILE( COPY ${CMAKE_CURRENT_SOURCE_DIR}/protobuf_defs
        DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
      )
  # Glob the (previously) protoc-compiled files for creating a dependency
  # to the MatlabBridge target
  FILE( GLOB PROTO_COMPILED_FILES ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs )

ELSE()
  IF( NOT PROTOBUF_PROTOC_EXECUTABLE
        OR NOT COMMAND PROTOBUF_GENERATE_PYTHON
        OR NOT COMMAND PROTOBUF_GENERATE_MATLAB )
      MESSAGE( SEND_ERROR "Google protobuf compiler or corresponding CMake configuration not found.")
  ENDIF()
  # create .py and .m protobuf language bindings:
  # protoc -I=. --python_out=./protobuf_defs protobuf_defs.proto
  # protoc -I=. --matlab_out=./protobuf_defs protobuf_defs.proto
  # note: the files in protobuflib/ are needed to generate the matlab protobuf_defs
  SET(PROTOBUF_DEFS_DIR ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs)
  MAKE_DIRECTORY(${PROTOBUF_DEFS_DIR})
  PROTOBUF_GENERATE_PYTHON( PB_PY_FILES ${PROTOBUF_DEFS_DIR} protobuf_defs.proto )
  PROTOBUF_GENERATE_MATLAB( PB_M_FILES ${PROTOBUF_DEFS_DIR} protobuf_defs.proto )
  # don't forget to add the __init__.py file to the protobuf_defs dir
  FILE( COPY ${CMAKE_CURRENT_SOURCE_DIR}/protobuf_defs/__init__.py
      DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs/
    )
ENDIF()

#Since the demo is in a different git project copy it to the demo
#directory
FILE( COPY ${CMAKE_CURRENT_SOURCE_DIR}/track_kalman.py
      DESTINATION ${CMAKE_SOURCE_DIR}/demo
    )

#Copy required py and m files to build dir
FOREACH( ITEM ${MATLAB_BRIDGE_M_SOURCE_FILES}) 
    FILE( COPY ${ITEM}
          DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
ENDFOREACH() 
FOREACH( ITEM ${MATLAB_BRIDGE_PY_SOURCE_FILES}) 
    FILE( COPY ${ITEM}
          DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
ENDFOREACH() 

#Copy the protobuflib directory to binary dir
FILE( COPY ${CMAKE_CURRENT_SOURCE_DIR}/protobuflib
        DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
      )
# install the matlab bridge in the install directory 
IF( NOT ${BUILD_3RDPARTY_PACKAGE} )
  INSTALL( DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs
                     ${CMAKE_CURRENT_BINARY_DIR}/protobuflib
           DESTINATION algorithms/matlab-bridge
           COMPONENT Runtime
         )
  INSTALL( FILES ${MATLAB_BRIDGE_PY_SOURCE_FILES}
           DESTINATION algorithms/matlab-bridge
           COMPONENT Runtime
         )
  INSTALL( FILES ${MATLAB_BRIDGE_M_SOURCE_FILES}
           DESTINATION algorithms/matlab-bridge
           COMPONENT Runtime
         )
  INSTALL( FILES track_kalman.py
           DESTINATION demo
           COMPONENT Runtime
         )
ENDIF( NOT ${BUILD_3RDPARTY_PACKAGE} )

ADD_CUSTOM_TARGET( MatlabBridge ALL DEPENDS
  ${MATLAB_BRIDGE_PY_SOURCE_FILES} ${PROTO_COMPILED_FILES} ${PB_PY_FILES} ${PB_M_FILES})
