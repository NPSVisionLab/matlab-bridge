%% Matlab Kalman example similar to
% http://www.mathworks.com/help/vision/ug/object-tracking.html,
% modified to work as EasyCV service via the MatlabBridge.
% Matz Oct 2014

% main Matlab function which gets invoked from MatlabBridge.py
function [] = kalman_tracker()
    % turn off warning for one-based coordinate system
    warning('off','vision:transition:usesOldCoordinates')
    
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
function [trackedLocations] = detectAndTrack( inputVideoPath, framepaths, videotype, easy_data_dir )
    trackedLocations = [];
    foregroundDetector = vision.ForegroundDetector('NumTrainingFrames', 10, 'InitialVariance', 0.05);
    blobAnalyzer = vision.BlobAnalysis('AreaOutputPort', false, 'MinimumBlobArea', 70);
    kalmanFilter = []; isTrackInitialized = false;
    fcnt = 0;
    
    % The method of stepping through the video depends on videotype
    if ( videotype == 1 ) % single video file
        display( ['debug: attempting detectAndTrack on file ' inputVideoPath] )
        try
            videoReader = vision.VideoFileReader(inputVideoPath);
        catch err
            if (strcmp(err.identifier,'dspshared:dspmmfileinfo:unavailableFile'))
                display( ['warn: file not found, skipping: ' inputVideoPath] )
                return;
            else
                rethrow(err);
            end
        end
        
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
    else % video is represented by multiple images
        display( ['debug: attempting detectAndTrack on a video composed of a folder of frames' ] )
        num_frames = length( framepaths );
        for frmidx=1:num_frames
            framepath = strcat( easy_data_dir, '/', framepaths( frmidx ).path );
            colorImage  = imread( framepath );
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
        end % for
    end
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
    % nclass  = length( in_protobuf_msg.run.purposedLists.purlist );
    % display( [ 'debug: Number of classes in the runset: ' num2str(nclass) ] )

    % iterate over artifacts in runset
    count = 1;
    for plidx = 1:length(in_protobuf_msg.run.purposedLists.purlist)
        % purpose = plist.pur.ptype;
        % display( [ 'debug: Artifacts of type: ' num2str(purpose) ':' ] )
        arts = in_protobuf_msg.run.purposedLists.purlist(plidx).labeledArtifacts;
        for artidx = 1:length(arts.labelable)
            display( ['debug: Will process artifact ' arts.labelable(artidx).vidSub.videopath.filename ] );
            % call the appropriate function depending on whether or not
            % the video consists of a single video file or multiple images
            % (frames)
            if ( isempty( arts.labelable(artidx).vidSub.framepaths ) && isempty( arts.labelable(artidx).vidSub.videopath ) )
                display( ['debug: video substrate is empty'] );
            elseif ( isempty( arts.labelable(artidx).vidSub.framepaths ) )
                % relative_path is relative to Easy data directory
                display( ['debug: video is a single video file'] );
                videotype = 1;
            else
                display( ['debug: video is composed of multiple image files: ' int2str( length( arts.labelable(artidx).vidSub.framepaths ) ) ] );
                videotype = 0;
            end
            videopath = fullfile( easy_data_dir, ...
                                 arts.labelable(artidx).vidSub.videopath.directory.relativePath, ...
                                 arts.labelable(artidx).vidSub.videopath.filename );
            framepaths = arts.labelable(artidx).vidSub.framepaths;
            positions = detectAndTrack( videopath, framepaths, videotype, easy_data_dir );
                
            %display( ['warn: FAKING processing of artifact ' filepath] );
            %positions = [25 49; 35 59; 32 63];
            
            % change from Matlab one-based coordinate system to
            % EasyCV zero-based coordinates.
            positions = minus(positions,1);

            % insert the positions into the ResultSet as a track
            resultset = setPositions( in_protobuf_msg, resultset, count, plidx, artidx, positions );
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

    % on Windows, write a semaphore file that is waited on in the
    % Python code
    if ispc
        touch = fopen( [msg_path '.done'], 'w');
        fclose(touch);
    end

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
    
    resultset.results.rslt(count).original = pblib_set(resultset.results.rslt(count).original, 'vidSub', pb_read_VideoSubstrate());
    resultset.results.rslt(count).original.vidSub = pblib_set(resultset.results.rslt(count).original.vidSub, 'videopath', pb_read_FilePath());
    resultset.results.rslt(count).original.vidSub.videopath = pblib_set(resultset.results.rslt(count).original.vidSub.videopath, 'directory', pb_read_DirectoryPath());
    resultset.results.rslt(count).original.vidSub.videopath.directory = pblib_set(resultset.results.rslt(count).original.vidSub.videopath.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.videopath.directory.relativePath);
    resultset.results.rslt(count).original.vidSub.videopath = pblib_set(resultset.results.rslt(count).original.vidSub.videopath, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.videopath.filename);
    resultset.results.rslt(count).original.vidSub = pblib_set(resultset.results.rslt(count).original.vidSub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.width);
    resultset.results.rslt(count).original.vidSub = pblib_set(resultset.results.rslt(count).original.vidSub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.height);

    resultset.results.rslt(count) = pblib_set(resultset.results.rslt(count), 'foundLabels', pb_read_LabelableList());
    resultset.results.rslt(count).foundLabels = pblib_set(resultset.results.rslt(count).foundLabels, 'labeledTrack', pb_read_LabeledTrack());
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'confidence', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).confidence);
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'lab', pb_read_Label());
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'hasLabel', true);
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'name', 'b-track');
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'properties',  pb_read_LabelProperties());
    resultset.results.rslt(count).foundLabels.labeledTrack.lab = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab, 'semantix',  pb_read_Semantics());
    resultset.results.rslt(count).foundLabels.labeledTrack.lab.semantix = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.lab.semantix, 'url', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).lab.semantix.url);
    
    resultset.results.rslt(count).foundLabels.labeledTrack = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack, 'vidSub', pb_read_VideoSubstrate());
    resultset.results.rslt(count).foundLabels.labeledTrack.vidSub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.vidSub, 'videopath', pb_read_FilePath());
    resultset.results.rslt(count).foundLabels.labeledTrack.vidSub.videopath = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.vidSub.videopath, 'directory', pb_read_DirectoryPath());
    resultset.results.rslt(count).foundLabels.labeledTrack.vidSub.videopath.directory = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.vidSub.videopath.directory, 'relativePath', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.videopath.directory.relativePath);
    resultset.results.rslt(count).foundLabels.labeledTrack.vidSub.videopath = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.vidSub.videopath, 'filename', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.videopath.filename);
    resultset.results.rslt(count).foundLabels.labeledTrack.vidSub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.vidSub, 'width', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.width);
    resultset.results.rslt(count).foundLabels.labeledTrack.vidSub = pblib_set(resultset.results.rslt(count).foundLabels.labeledTrack.vidSub, 'height', in_protobuf_msg.run.purposedLists.purlist(pls).labeledArtifacts.labelable(art).vidSub.height);
   
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
