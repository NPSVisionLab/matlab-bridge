function [descriptor] = pb_descriptor_Label()
%pb_descriptor_Label Returns the descriptor for message Label.
%   function [descriptor] = pb_descriptor_Label()
%
%   See also pb_read_Label

  descriptor = struct( ...
    'name', 'Label', ...
    'full_name', 'Label', ...
    'filename', 'protobuf_defs.proto', ...
    'containing_type', '', ...
    'fields', [ ...
      struct( ...
        'name', 'hasLabel', ...
        'full_name', 'Label.hasLabel', ...
        'index', 1, ...
        'number', uint32(1), ...
        'type', uint32(8), ...
        'matlab_type', uint32(3), ...
        'wire_type', uint32(0), ...
        'label', uint32(1), ...
        'default_value', uint32(0), ...
        'read_function', @(x) pblib_helpers_first(typecast(x, 'uint32')), ...
        'write_function', @(x) typecast(uint32(x), 'uint32'), ...
        'options', struct('packed', false) ...
      ), ...
      struct( ...
        'name', 'name', ...
        'full_name', 'Label.name', ...
        'index', 2, ...
        'number', uint32(2), ...
        'type', uint32(9), ...
        'matlab_type', uint32(7), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', '', ...
        'read_function', @(x) char(x{1}(x{2} : x{3})), ...
        'write_function', @uint8, ...
        'options', struct('packed', false) ...
      ), ...
      struct( ...
        'name', 'properties', ...
        'full_name', 'Label.properties', ...
        'index', 3, ...
        'number', uint32(3), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_LabelProperties(x{1}, x{2}, x{3}), ...
        'write_function', @pblib_generic_serialize_to_string, ...
        'options', struct('packed', false) ...
      ), ...
      struct( ...
        'name', 'semantix', ...
        'full_name', 'Label.semantix', ...
        'index', 4, ...
        'number', uint32(4), ...
        'type', uint32(11), ...
        'matlab_type', uint32(9), ...
        'wire_type', uint32(2), ...
        'label', uint32(1), ...
        'default_value', struct([]), ...
        'read_function', @(x) pb_read_Semantics(x{1}, x{2}, x{3}), ...
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
