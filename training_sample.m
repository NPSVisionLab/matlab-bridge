% You must add the protobuf language bindings to MATLAB's path
% so that you can access protobuf message contents.
% The protobuf language bindings are located in the Easy! 
% root directory under algorithms/matlab-bridge.
% MatlabBridge.py passes to this entry function the absolute
% path of the Matlab bridge folder (i.e.
% /Applications/EasyComputerVision.app/Contents/Resources/algorithms/matlab-bridge
% ) via a variable named 'matlab_bridge_dir'
% Add this to the path as follows:

display( [ 'Protobuf language bindings location: ' matlab_bridge_dir ] )
addpath( genpath( matlab_bridge_dir ) );

% MatlabBridge.py also passes to this entry function the absolute
% path of the protobuf message via a variable called 'msg_path'

display( [ 'Matlab service message: ' msg_path ] )

% Retrieve the protobuf message from msg_path as follows:
display( 'Retrieving the message' )
fid = fopen( msg_path );
in_buffer = fread(fid, [1 inf], '*uint8');
in_protobuf_msg = pb_read_MatlabBridgeMsg(in_buffer);

% Close and remove the protobuf message
fclose(fid);
delete(msg_path);

% Depending on the matlab service that you've developed, you
% might want to check the message contents to be sure that
% the service had been defined properly. For example, if your
% service is a training service, you might want to check
% to make sure that runset isn't empty. This might be done
% as follows:
if( isempty( in_protobuf_msg.run ) )
    display( 'No runset provided. You should probably provide one.' )
else
    display( 'A runset has been provided. Thanks.' )
end

% Take a look at the contents of a protobuf message (protobuf_defs.proto)
display( ' ' )
display( '--- Contents of a protobuf message ---' )
in_protobuf_msg

% Access its contents as follows
%%% Runset %%%
display( '--- Runset elements ---' )

%   number of classes in runset
nclass  = length( in_protobuf_msg.run.purposedLists.purlist );
display( [ 'Number of classes in the runset: ' num2str(nclass) ] )

%   types of classes in runset
display( 'Types of classes in the runset: ' )
for i=1:nclass
    type = in_protobuf_msg.run.purposedLists.purlist(i).pur.ptype;
    if( type == 1 )
        display( 'POSITIVE' )
    elseif ( type == 2 )
        display( 'NEGATIVE' )
    end
end

%   number of artifacts in runset
Ntrain = 0;
for c=1:nclass
    Ntrain = Ntrain + length(in_protobuf_msg.run.purposedLists.purlist(c).labeledArtifacts.labelable);
end
display( [ 'Total number of runset artifacts: ' num2str(Ntrain) ] )

%   file path of artifacts in runset
%       'easy_data_dir' is created and passed by MatlabBridge.py
display( [ 'Easy data directory: ' easy_data_dir ] )
display( 'File paths of runset artifacts: ' )
for c=1:nclass
    purpose = in_protobuf_msg.run.purposedLists.purlist(c).pur.ptype;
    display( [ 'Artifacts of type: ' num2str(purpose) ':' ] )
    num_artifacts = length(in_protobuf_msg.run.purposedLists.purlist(c).labeledArtifacts.labelable);
    for a=1:num_artifacts
        % relative_path is relative to Easy data directory
        relative_path = in_protobuf_msg.run.purposedLists.purlist(c).labeledArtifacts.labelable(a).sub.path.directory.relativePath;
        file_name = in_protobuf_msg.run.purposedLists.purlist(c).labeledArtifacts.labelable(a).sub.path.filename;
        display( char( strcat( easy_data_dir, '/', relative_path, '/', file_name ) ) )
    end
end

%%% Service Properties %%%
% These are set by the client to be used by your matlab training or detection 
% service
display( ' ' )
display( '--- Service Properites (key,value) ---' )
num_keys = length(in_protobuf_msg.props);
for k=1:num_keys
    display( [ '(' in_protobuf_msg.props(k).key ',' in_protobuf_msg.props(k).value ')' ] )
end

%%% Model Setting %%%
display( ' ' )
display( '--- Model setting ---' )
%   OB_screenshot.mat is the output of your training evolution
model_filename = 'OB_screenshot.mat'
%   model_path is where you saved your model
model_path = char( strcat( easy_data_dir, '/detectors' ) )
in_protobuf_msg = pblib_set(in_protobuf_msg, 'model', pb_read_Model());
in_protobuf_msg.model = pblib_set(in_protobuf_msg.model, 'mPath', pb_read_FilePath());
in_protobuf_msg.model.mPath = pblib_set(in_protobuf_msg.model.mPath, 'filename', model_filename);
in_protobuf_msg.model.mPath = pblib_set(in_protobuf_msg.model.mPath, 'directory', pb_read_DirectoryPath());
in_protobuf_msg.model.mPath.directory = pblib_set(in_protobuf_msg.model.mPath.directory, 'relativePath', model_path); 

%%% Convert to protobuf message %%%
display( ' ' )
display( '--- Convert to protobuf message ---' )
out_buffer = pblib_generic_serialize_to_string(in_protobuf_msg);
fod = fopen( msg_path, 'w');
fwrite(fod, out_buffer, 'uint8');
fclose(fod);
display( '--- The End ---' )