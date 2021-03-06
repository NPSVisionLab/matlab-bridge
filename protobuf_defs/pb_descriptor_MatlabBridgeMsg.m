function [descriptor] = pb_descriptor_MatlabBridgeMsg()
%pb_descriptor_MatlabBridgeMsg Returns the descriptor for message MatlabBridgeMsg.
%   function [descriptor] = pb_descriptor_MatlabBridgeMsg()
%
%   See also pb_read_MatlabBridgeMsg
  
  descriptor = struct( ...
    'name', 'MatlabBridgeMsg', ...
    'full_name', 'MatlabBridgeMsg', ...
    'filename', 'protobuf_defs.proto', ...
    'containing_type', '', ...
    'fields', [ ...
      struct( ...
        'name', 'run', ...
        'full_name', 'MatlabBridgeMsg.run', ...
        'index', 1, ...
        'number', uint32(1), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_RunSet(x{1}, x{2}, x{3}), ...
        'write_function', @pblib_generic_serialize_to_string, ...
        'options', struct('packed', false) ...
      ), ...
      struct( ...
        'name', 'props', ...
        'full_name', 'MatlabBridgeMsg.props', ...
        'index', 2, ...
        'number', uint32(2), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(3), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_Properties(x{1}, x{2}, x{3}), ...
        'write_function', @pblib_generic_serialize_to_string, ...
        'options', struct('packed', false) ...
      ), ...
      struct( ...
        'name', 'res', ...
        'full_name', 'MatlabBridgeMsg.res', ...
        'index', 3, ...
        'number', uint32(3), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_ResultSet(x{1}, x{2}, x{3}), ...
        'write_function', @pblib_generic_serialize_to_string, ...
        'options', struct('packed', false) ...
      ), ...
      struct( ...
        'name', 'model', ...
        'full_name', 'MatlabBridgeMsg.model', ...
        'index', 4, ...
        'number', uint32(4), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_Model(x{1}, x{2}, x{3}), ...
        'write_function', @pblib_generic_serialize_to_string, ...
        'options', struct('packed', false) ...
      ) ...
    ], ...
    'extensions', [ ... % Not Implemented
    ], ...
    'nested_types', [ ... % Not implemented
    ], ...
    'enum_types', [ ... % Not Implemented
    ], ...
    'options', [ ... % Not Implemented
    ] ...
  );
  
  descriptor.field_indeces_by_number = java.util.HashMap;
  put(descriptor.field_indeces_by_number, uint32(1), 1);
  put(descriptor.field_indeces_by_number, uint32(2), 2);
  put(descriptor.field_indeces_by_number, uint32(3), 3);
  put(descriptor.field_indeces_by_number, uint32(4), 4);
  
