function [descriptor] = pb_descriptor_ResultSet()
%pb_descriptor_ResultSet Returns the descriptor for message ResultSet.
%   function [descriptor] = pb_descriptor_ResultSet()
%
%   See also pb_read_ResultSet
  
  descriptor = struct( ...
    'name', 'ResultSet', ...
    'full_name', 'ResultSet', ...
    'filename', 'protobuf_defs.proto', ...
    'containing_type', '', ...
    'fields', [ ...
      struct( ...
        'name', 'results', ...
        'full_name', 'ResultSet.results', ...
        'index', 1, ...
        'number', uint32(1), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_ResultList(x{1}, x{2}, x{3}), ...
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
  
