%% Matlab Kalman example similar to
% http://www.mathworks.com/help/vision/ug/object-tracking.html,
% modified to work as EasyCV service via the MatlabBridge.
% Matz Oct 2014

% main Matlab function which gets invoked from MatlabBridge.py
function [] = kalman_tracker()
    
    display( 'debug: entered Matlab code.' )
    % fetch variables from the base workspace;
    % MatlabBridge.py defines these
    msg_path = evalin('base','msg_path');
    matlab_bridge_dir = evalin('base','matlab_bridge_dir');
    easy_data_dir = evalin('base','easy_data_dir');

    trackerService(msg_path, matlab_bridge_dir, easy_data_dir);
    display( 'debug: exiting Matlab code.' )
end

% the actual tracking function; makes lots of assumptions on the scene
% and motion
function [trackedLocations] = detectAndTrack( inputVideoFile )
    
    display( ['debug: attempting detectAndTrack on file ' inputVideoFile] )
    trackedLocations = [];
    try
        videoReader = vision.VideoFileReader(inputVideoFile);
    catch err
        if (strcmp(err.identifier,'dspshared:dspmmfileinfo:unavailableFile'))
            display( ['warn: file not found, skipping: ' inputVideoFile] )
            return;
        else
            rethrow(err);
        end
    end
    foregroundDetector = vision.ForegroundDetector('NumTrainingFrames', 10, 'InitialVariance', 0.05);
    blobAnalyzer = vision.BlobAnalysis('AreaOutputPort', false, 'MinimumBlobArea', 70);

    kalmanFilter = []; isTrackInitialized = false;
    fcnt = 0;
    while ~isDone(videoReader)
        colorImage  = step(videoReader);
        fcnt = fcnt+1;
        trackedLocations = [trackedLocations; NaN NaN]; %#ok<AGROW>
    
        foregroundMask = step(foregroundDetector, rgb2gray(colorImage));
        detectedLocation = step(blobAnalyzer, foregroundMask);
        isObjectDetected = size(detectedLocation, 1) > 0;
    
        if ~isTrackInitialized
            if isObjectDetected
                kalmanFilter = configureKalmanFilter('ConstantAcceleration', ...
                                                     detectedLocation(1,:), ...
                                                     [1 1 1]*1e5, [25, 10, 10], 25); 
                isTrackInitialized = true;
            end
        else
            if isObjectDetected
                % Reduce the measurement noise by calling predict, then correct
                % predictedLocation = predict(kalmanFilter);
                trackedLocation = correct(kalmanFilter, detectedLocation(1,:));
            else % Object is missing
                trackedLocation = predict(kalmanFilter);
            end
            trackedLocations(fcnt,:) = trackedLocation;
        end
    end % while

    release(videoReader);

end % function

    
% protobuf conversion, parsing of messages, 
function [] = trackerService( msg_path, matlab_bridge_dir, easy_data_dir )
    
    % display( [ 'debug: Protobuf language bindings location: ' matlab_bridge_dir ] )
    % display( [ 'debug: Matlab service message: ' msg_path ] )
    % display( [ 'debug: EasyCV data directory: ' easy_data_dir ] )
    addpath( genpath( matlab_bridge_dir ) );

    % Retrieve the protobuf message from msg_path as follows:
    fid = fopen( msg_path );
    in_buffer = fread(fid, [1 inf], '*uint8');
    in_protobuf_msg = pb_read_MatlabBridgeMsg(in_buffer);

    % Close and remove the protobuf message
    fclose(fid);
    delete(msg_path);

    % we don't expect to see a model file for this tracker;
    % complain if we do
    if( ~isempty( in_protobuf_msg.model.mPath.directory.relativePath ) || ...
        ~isempty( in_protobuf_msg.model.mPath.filename ) )
        display( ['warn: Kalman tracker does not require a model, ' ...
                  'but a model was specified:'])
        in_protobuf_msg.model.mPath.directory.relativePath
        in_protobuf_msg.model.mPath.filename
    end

    %   create the resultset container
    resultset = pb_read_ResultSet();
    resultset = pblib_set(resultset, 'results', pb_read_ResultList());
    resultset.results = pblib_set(resultset.results, 'rslt', pb_read_Result());

    % fill the ResultSet with the originals
    % resultset = tempSetAll( in_protobuf_msg, resultset );

    %   number of classes in runset
    nclass  = length( in_protobuf_msg.run.purposedLists.purlist );
    % display( [ 'debug: Number of classes in the runset: ' num2str(nclass) ] )

    % iterate over artifacts in runset
    count = 1;
    for c=1:nclass
        % purpose = in_protobuf_msg.run.purposedLists.purlist(c).pur.ptype;
        % display( [ 'debug: Artifacts of type: ' num2str(purpose) ':' ] )
        arts = in_protobuf_msg.run.purposedLists.purlist(c).labeledArtifacts;
        num_artifacts = length(arts.labelable);
        for a=1:num_artifacts
            % relative_path is relative to Easy data directory
            filepath = fullfile( easy_data_dir, ...
                                 arts.labelable(a).sub.path.directory.relativePath, ...
                                 arts.labelable(a).sub.path.filename );
            % display( ['debug: Will process artifact ' filepath] );
            % positions = detectAndTrack( filepath );
            display( ['warn: FAKING processing of artifact ' filepath] );
            positions = [25 49; 35 59; 32 63];
            
            % insert the positions into the ResultSet as a track
            %todo: [resultset result] = addResult( resultset, arts.labelable(a) );
            %pbTrack = createPbTrack( positions );
            %todo: addFoundLabelable( result, pbTrack );
            resultset = setPositions( in_protobuf_msg, resultset, count, c, a, positions );
            count = count + 1;
        end
    end

    % set the result
    in_protobuf_msg = pblib_set(in_protobuf_msg, 'res', resultset);

    % Convert to protobuf message
    display( ['debug: Converting result to protobuf message in ' msg_path '.'] )
    out_buffer = pblib_generic_serialize_to_string(in_protobuf_msg);
    fod = fopen( msg_path, 'w');
    fwrite(fod, out_buffer, 'uint8');
    fclose(fod);
end

    
% create an EasyCV LabeledTrack in protobuf format from a matrix of locations
function [pbtrack] = createPbTrack( positions )
    pbtrack = pb_read_Labelable();
    pbtrack = pblib_set(pbtrack, 'labelable', pb_read_Labelable());
    pbtrack.labelable = pblib_set(pbtrack.labelable, 'confidence', 1.0);
    pbtrack.labelable = pblib_set(pbtrack.labelable, 'lab', pb_read_Label());
    pbtrack.labelable.lab = pblib_set(pbtrack.labelable.lab, 'hasLabel', true);
    pbtrack.labelable.lab = pblib_set(pbtrack.labelable.lab, 'name', 'b-track');

    % TODO create the LabeledTrack:
    % FrameLocationList keyframesLocations;
    % Interpolation interp = DISCRETE;
    %
    % FrameLocation {VideoSeekTime frame; Location loc = from positions;
    % bool occluded = false; bool outOfFrame = false; }
    % 
    % VideoSeekTime { long time=-1; long framecnt = index into positions }
    % 
end


% Add the foundLabelable to the list of already found labels for the 
% given result.
function [result] = addFoundLabelable( result, foundLabelable )
    % todo: check that this appends at the end of the list
    result.foundLabels(end) = pblib_set(result.foundLabels(end), ...
                                        'labelable', foundLabelable);
end


% Create a new result for the given original, with an empty list for foundLabels.
function [resultset, result] = addResult( resultset, orig )
    % todo: check that this appends at the end of the list
    resultset.results.rslt = [resultset.results.rslt pb_read_Result()];
    
    % copy the original into the Result
    resultset.results.rslt(end) = pblib_set(resultset.results.rslt(end), 'original', orig);
    theend = resultset.results.rslt(end);
    resultset.results.rslt(end).original = pblib_set(theend.original, 'confidence', orig.confidence);
    resultset.results.rslt(end).original = pblib_set(theend.original, 'lab', pb_read_Label());
    resultset.results.rslt(end).original.lab = pblib_set(theend.original.lab, 'hasLabel', orig.lab.hasLabel);
    resultset.results.rslt(end).original.lab = pblib_set(theend.original.lab, 'name', orig.lab.name);
    resultset.results.rslt(end).original.lab = pblib_set(theend.original.lab, 'properties',  pb_read_LabelProperties());
    resultset.results.rslt(end).original.lab = pblib_set(theend.original.lab, 'semantix',  pb_read_Semantics());
    resultset.results.rslt(end).original.lab.semantix = pblib_set(theend.original.lab.semantix, 'url', orig.lab.semantix.url);
    resultset.results.rslt(end).original = pblib_set(theend.original, 'sub', pb_read_Substrate());
    resultset.results.rslt(end).original.sub = pblib_set(theend.original.sub, 'isImage', orig.sub.isImage);
    resultset.results.rslt(end).original.sub = pblib_set(theend.original.sub, 'isVideo', orig.sub.isVideo);
    resultset.results.rslt(end).original.sub = pblib_set(theend.original.sub, 'path', pb_read_FilePath());
    resultset.results.rslt(end).original.sub.path = pblib_set(theend.original.sub.path, 'directory', pb_read_DirectoryPath());
    resultset.results.rslt(end).original.sub.path.directory = pblib_set(theend.original.sub.path.directory, 'relativePath', orig.sub.path.directory.relativePath);
    resultset.results.rslt(end).original.sub.path = pblib_set(theend.original.sub.path, 'filename', orig.sub.path.filename);
    resultset.results.rslt(end).original.sub = pblib_set(theend.original.sub, 'width', orig.sub.width);
    resultset.results.rslt(end).original.sub = pblib_set(theend.original.sub, 'height', orig.sub.height);
    
    % create space for the foundLabels
    resultset.results.rslt(end) = pblib_set(theend, 'foundLabels', pb_read_LabelableList());
    result = resultset.results.rslt;
end

% copied from sample code: set all of the individual results
function [resultset] = tempSetAll( in_protobuf_msg, resultset )
    count = 1;
    for pls = 1:length(in_protobuf_msg.run.purposedLists.purlist)
        for art = 1:length(in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable)
            fprintf('===> %d\n', count);
            resultset.results.rslt(count) = pb_read_Result();
            resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'original', pb_read_Labelable());
            resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
            resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'lab', pb_read_Label());
            resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'hasLabel', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.hasLabel);
            resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'name', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.name);
            resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'properties',  pb_read_LabelProperties());
            resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'semantix',  pb_read_Semantics());
            resultset.results.rslt(count).original.lab.semantix = pblib_set(resultset.results.rslt(count).original.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
            resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'sub', pb_read_Substrate());
            resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'isImage', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isImage);
            resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'isVideo', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isVideo);
            resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'path', pb_read_FilePath());
            resultset.results.rslt(count).original.sub.path = pblib_set(resultset.results.rslt(count).original.sub.path, 'directory', pb_read_DirectoryPath());
            resultset.results.rslt(count).original.sub.path.directory = pblib_set(resultset.results.rslt(count).original.sub.path.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.directory.relativePath);
            resultset.results.rslt(count).original.sub.path = pblib_set(resultset.results.rslt(count).original.sub.path, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.filename);
            resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.width);
            resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.height);

            resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'foundLabels', pb_read_LabelableList());
            resultset.results.rslt(count).foundLabels = pblib_set(resultset.results.rslt(count).foundLabels, 'labelable', pb_read_Labelable());
            resultset.results.rslt(count).foundLabels.labelable = pblib_set(resultset.results.rslt(count).foundLabels.labelable, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
            resultset.results.rslt(count).foundLabels.labelable = pblib_set(resultset.results.rslt(count).foundLabels.labelable, 'lab', pb_read_Label());
            resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'hasLabel', true);

            %%This is where you might fill in the result of your detection %%%
            resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'name', 'a-track');

            resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'properties',  pb_read_LabelProperties());
            resultset.results.rslt(count).foundLabels.labelable.lab = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab, 'semantix',  pb_read_Semantics());
            resultset.results.rslt(count).foundLabels.labelable.lab.semantix = pblib_set(resultset.results.rslt(count).foundLabels.labelable.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
            resultset.results.rslt(count).foundLabels.labelable = pblib_set(resultset.results.rslt(count).foundLabels.labelable, 'sub', pb_read_Substrate());
            resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'isImage', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isImage);
            resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'isVideo', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isVideo);
            resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'path', pb_read_FilePath());
            resultset.results.rslt(count).foundLabels.labelable.sub.path = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub.path, 'directory', pb_read_DirectoryPath());
            resultset.results.rslt(count).foundLabels.labelable.sub.path.directory = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub.path.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.directory.relativePath);
            resultset.results.rslt(count).foundLabels.labelable.sub.path = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub.path, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.filename);
            resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.width);
            resultset.results.rslt(count).foundLabels.labelable.sub = pblib_set(resultset.results.rslt(count).foundLabels.labelable.sub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.height);

            count = count + 1;
        end
    end
end

function [resultset] = setPositions( in_protobuf_msg, resultset, count, pls, art, positions )
    resultset.results.rslt(count) = pb_read_Result();
    resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'original', pb_read_Labelable());
    resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
    resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'lab', pb_read_Label());
    resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'hasLabel', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.hasLabel);
    resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'name', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.name);
    resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'properties',  pb_read_LabelProperties());
    resultset.results.rslt(count).original.lab = pblib_set(resultset.results.rslt(count).original.lab, 'semantix',  pb_read_Semantics());
    resultset.results.rslt(count).original.lab.semantix = pblib_set(resultset.results.rslt(count).original.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
    resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'sub', pb_read_Substrate());
    resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'isImage', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isImage);
    resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'isVideo', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isVideo);
    resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'path', pb_read_FilePath());
    resultset.results.rslt(count).original.sub.path = pblib_set(resultset.results.rslt(count).original.sub.path, 'directory', pb_read_DirectoryPath());
    resultset.results.rslt(count).original.sub.path.directory = pblib_set(resultset.results.rslt(count).original.sub.path.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.directory.relativePath);
    resultset.results.rslt(count).original.sub.path = pblib_set(resultset.results.rslt(count).original.sub.path, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.filename);
    resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.width);
    resultset.results.rslt(count).original.sub = pblib_set(resultset.results.rslt(count).original.sub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.height);

    resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'foundLabels', pb_read_LabelableList());
    resultset.results.rslt(count).foundLabels = pblib_set(resultset.results.rslt(count).foundLabels, 'labeledTrack', pb_read_LabeledTrack());
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'lab', pb_read_Label());
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'hasLabel', true);
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'name', 'b-track');
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'properties',  pb_read_LabelProperties());
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'semantix',  pb_read_Semantics());
    resultset.results.rslt(count).foundLabels.labeledTrack.lab.semantix = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
    
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'sub', pb_read_Substrate());
    resultset.results.rslt(count).foundLabels.labeledTrack.sub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub, 'isImage', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isImage);
    resultset.results.rslt(count).foundLabels.labeledTrack.sub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub, 'isVideo', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.isVideo);
    resultset.results.rslt(count).foundLabels.labeledTrack.sub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub, 'path', pb_read_FilePath());
    resultset.results.rslt(count).foundLabels.labeledTrack.sub.path = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub.path, 'directory', pb_read_DirectoryPath());
    resultset.results.rslt(count).foundLabels.labeledTrack.sub.path.directory = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub.path.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.directory.relativePath);
    resultset.results.rslt(count).foundLabels.labeledTrack.sub.path = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub.path, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.path.filename);
    resultset.results.rslt(count).foundLabels.labeledTrack.sub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.width);
    resultset.results.rslt(count).foundLabels.labeledTrack.sub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.sub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).sub.height);
   
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'keyframesLocations', pb_read_FrameLocationList());
    resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations, 'framelocation', pb_read_FrameLocation());
    
    num_frames = length(positions);
    for f=1:num_frames
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f) = pb_read_FrameLocation();
        
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f) = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f), 'frame', pb_read_VideoSeekTime());
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).frame = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).frame, 'time', -1);
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).frame = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).frame, 'framecnt', f);
        
        %%This is where you might fill in the result of your detection %%%
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f) = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f), 'loc', pb_read_Point2D());
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).loc = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).loc, 'x', positions(f,1));
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).loc = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f).loc, 'y', positions(f,2));
        
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f) = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f), 'occluded', false);
        resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f) = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.keyframesLocations.framelocation(f), 'outOfFrame', false);
    end
    
    %resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'interp', pb_read_Interpolation());    
end
