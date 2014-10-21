% You must add the protobuf language bindings to MATLAB's path
% so that you can access protobuf message contents.
% The protobuf language bindings are located in the Easy! 
% root directory under algorithms/matlab-bridge.
% MatlabBridge.py passes to this entry function the absolute
% path of the matlab-bridge folder (i.e.
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
% service is a detection service, you might want to check
% to make sure that model isn't empty. This might be done
% as follows:
if( isempty( in_protobuf_msg.model ) )
    display( 'No model provided. How am I supposed to do detection?' )
else
    display( 'A model has been provided. Thanks.' )
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

%%% Service Definition (Properties) %%%
% These are set by the client to be used by your matlab training or detection 
% service
display( ' ' )
display( '--- Service Properites (key,value) ---' )
num_keys = length(in_protobuf_msg.serviceDef);
for k=1:num_keys
    display( [ '(' in_protobuf_msg.serviceDef(k).key ',' in_protobuf_msg.serviceDef(k).value ')' ] )
end

%%% Model Getting %%%
display( ' ' )
display( '--- Model getting ---' )
display( 'Model relative path: ' )
in_protobuf_msg.model.mPath.directory.relativePath
display( 'Model filename: ' )
in_protobuf_msg.model.mPath.filename
display( 'Loading the model: ' )
% You would want to load the model with a command like:
% model = load( the_path_to_the_model );

%%% Result Setting %%%
display( ' ' )
display( '--- Result setting ---' )

%   create the resultset container
resultset = pb_read_ResultSet();
resultset = pblib_set(resultset, 'results', pb_read_ResultList());
resultset.results = pblib_set(resultset.results, 'rslt', pb_read_Result());

%   set all of the individual results
% count = 1;
% for pls = 1:length(in_protobuf_msg.run.purposedLists.purlist)
%     for art = 1:length(in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable)
%         resultset.results.rslt(count) = pb_read_Result();
%         resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'original', pb_read_Labelable());
%         resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
%         resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'lab', pb_read_Label());
%         resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'hasLabel', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.hasLabel);
%         resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'name', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.name);
%         resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'properties',  pb_read_LabelProperties());
%         resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'semantix',  pb_read_Semantics());
%         resultset.results.rslt(count).original.lab.semantix = pblib_set(resultset.results.rslt(count).original.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
%         resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'sub', pb_read_Substrate());
%         resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'isImage', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isImage);
%         resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'isVideo', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isVideo);
%         resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'path', pb_read_FilePath());
%         resultset.results.rslt(count).original.sub.path = pblib_set(resultset.results.rslt(count).original.sub.path, 'directory', pb_read_DirectoryPath());
%         resultset.results.rslt(count).original.sub.path.directory = pblib_set(resultset.results.rslt(count).original.sub.path.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.directory.relativePath);
%         resultset.results.rslt(count).original.sub.path = pblib_set(resultset.results.rslt(count).original.sub.path, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.filename);
%         resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.width);
%         resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.height);
% 
%         resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'foundLabels', pb_read_LabelableList());
%         resultset.results.rslt(count).foundLabels = pblib_set(resultset.results.rslt(count).foundLabels, 'labelable', pb_read_Labelable());
%         resultset.results.rslt(count).foundLabels.labelable = pblib_set(resultset.results.rslt(count).foundLabels.labelable, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
%         resultset.results.rslt(count).foundLabels.labelable = pblib_set(resultset.results.rslt(count).foundLabels.labelable, 'lab', pb_read_Label());
%         resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'hasLabel', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.hasLabel);
%         
%         %%% This is where you might fill in the result of your detection %%%
%         resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'name', YOUR_COMPUTED_LABEL(count));
%         
%         resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'properties',  pb_read_LabelProperties());
%         resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'semantix',  pb_read_Semantics());
%         resultset.results.rslt(count).foundLabels.labelable.lab.semantix = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
%         resultset.results.rslt(count).foundLabels.labelable = pblib_set(resultset.results.rslt(count).foundLabels.labelable, 'sub', pb_read_Substrate());
%         resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'isImage', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isImage);
%         resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'isVideo', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isVideo);
%         resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'path', pb_read_FilePath());
%         resultset.results.rslt(count).foundLabels.labelable.sub.path = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub.path, 'directory', pb_read_DirectoryPath());
%         resultset.results.rslt(count).foundLabels.labelable.sub.path.directory = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub.path.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.directory.relativePath);
%         resultset.results.rslt(count).foundLabels.labelable.sub.path = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub.path, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.filename);
%         resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.width);
%         resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.height);
% 
%         count = count + 1;
%     end
% end

%   set the result
in_protobuf_msg = pblib_set(in_protobuf_msg, 'res', resultset);

%%% Convert to protobuf message %%%
display( ' ' )
display( '--- Convert to protobuf message ---' )
out_buffer = pblib_generic_serialize_to_string(in_protobuf_msg);
fod = fopen( msg_path, 'w');
fwrite(fod, out_buffer, 'uint8');
fclose(fod);
display( '--- The End ---' )