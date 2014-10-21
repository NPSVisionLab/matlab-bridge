function [labelable] = pb_read_Labelable(buffer, buffer_start, buffer_end)
%pb_read_Labelable Reads the protobuf message Labelable.
%   function [labelable] = pb_read_Labelable(buffer, buffer_start, buffer_end)
%
%   INPUTS:
%     buffer       : a buffer of uint8's to parse
%     buffer_start : optional starting index to consider of the buffer
%                    defaults to 1
%     buffer_end   : optional ending index to consider of the buffer
%                    defaults to length(buffer)
%
%   MEMBERS:
%     confidence     : optional single, defaults to single(0).
%     lab            : optional <a href="matlab:help pb_read_Label">Label</a>, defaults to struct([]).
%     sub            : optional <a href="matlab:help pb_read_Substrate">Substrate</a>, defaults to struct([]).
%
%   See also pb_read_Label, pb_read_Substrate, pb_read_MatlabBridgeMsg, pb_read_Model, pb_read_Properties, pb_read_Result, pb_read_ResultList, pb_read_ResultSet, pb_read_DirectoryPath, pb_read_FilePath, pb_read_Semantics, pb_read_LabelProperties, pb_read_LabeledTrack, pb_read_FrameLocationList, pb_read_FrameLocation, pb_read_VideoSeekTime, pb_read_Point2D, pb_read_LabelableList, pb_read_Purpose, pb_read_PurposedLabelableSeq, pb_read_PurposedListSequence, pb_read_RunSet.

  if (nargin < 1)
    buffer = uint8([]);
  end
  if (nargin < 2)
    buffer_start = 1;
  end
  if (nargin < 3)
    buffer_end = length(buffer);
  end

  descriptor = pb_descriptor_Labelable();
  labelable = pblib_generic_parse_from_string(buffer, descriptor, buffer_start, buffer_end);
  labelable.descriptor_function = @pb_descriptor_Labelable;
