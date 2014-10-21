# If protoc doesn't exist, just copy the pre-built language bindings
# from the source directory, to the build directory.
# Else, build them with protoc
INCLUDE( protobuf )

SET( MATLAB_BRIDGE_PY_SOURCE_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/MatlabBridge.py 
  ${CMAKE_CURRENT_SOURCE_DIR}/__init__.py )

IF( NOT PROTOBUF_PROTOC_EXECUTABLE OR NOT PROTO2PY OR NOT PROTO2MAT )
  MESSAGE( STATUS "Google protobuf compiler not found. Will use pre-built language bindings.")
  FILE( COPY ${CMAKE_CURRENT_SOURCE_DIR}/protobuf_defs
        DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
      )
ELSE()
  # create .py and .m protobuf language bindings:
  # protoc -I=. --python_out=./protobuf_defs protobuf_defs.proto
  # protoc -I=. --matlab_out=./protobuf_defs protobuf_defs.proto
  # note: the files in protobuflib/ are needed to generate the matlab protobuf_defs
  SET(PROTOBUF_DEFS_DIR ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs)
  MAKE_DIRECTORY(${PROTOBUF_DEFS_DIR})
  PROTO2PY( PBFILES protobuf_defs.proto )
  PROTO2MAT( PBFILES protobuf_defs.proto )
  # don't forget to add the __init__.py file to the protobuf_defs dir
  FILE( COPY ${CMAKE_CURRENT_SOURCE_DIR}/protobuf_defs/__init__.py
      DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs/
    )
ENDIF()

# Glob the protoc-compiled files for creating a dependency
# to the MatlabBridge target
FILE( GLOB PROTO_COMPILED_FILES ${CMAKE_CURRENT_BINARY_DIR}/protobuf_defs )

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
ENDIF( NOT ${BUILD_3RDPARTY_PACKAGE} )

ADD_CUSTOM_TARGET( MatlabBridge ALL DEPENDS
  ${MATLAB_BRIDGE_PY_SOURCE_FILES} ${PROTO_COMPILED_FILES} )
