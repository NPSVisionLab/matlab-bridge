import protobuf_defs.protobuf_defs_pb2 as pb
import os, sys
import threading, Ice
import IcePy
import easy
import cvac
import re   #for extracting ip address
from easy.util.ArchiveHandler import ArchiveHandler
import time
import datetime
import fileinput
from subprocess import Popen, PIPE, call
thisPath = os.path.dirname(os.path.abspath(__file__))
easyRoot = os.path.dirname(os.path.abspath(__file__+'/../../'))
dataPath = easyRoot + '/data'

def to_protobuf ( run, props, model=None ):
    # instantiate an empty service message
    msg = pb.MatlabBridgeMsg()
    
    # fill-out the specifics of the service being requested
    #   Service Definition
    for pidx, p in enumerate( props.props ):
        msg.props.add()
        msg.props[ pidx ].key = props.props.keys()[ pidx ]
        msg.props[ pidx ].value = props.props.values()[ pidx ]
    
    #   Service Runset
    for plidx, pls in enumerate( run.purposedLists ):
        # add an PurposedLabelableSeq object
        msg.run.purposedLists.purlist.add()
        # set the PurposedLabelableSeq object's Purpose fields (ptype, classID)
        # cvac.PurposeType.UNPURPOSED, cvac.PurposeType.POSITIVE,
        # cvac.PurposeType.NEGATIVE, cvac.PurposeType.MULTICLASS,
        # cvac.PurposeType.ANY
        if( pls.pur.ptype == cvac.PurposeType.UNPURPOSED ):
            msg.run.purposedLists.purlist[plidx].pur.ptype = 0
        elif( pls.pur.ptype == cvac.PurposeType.POSITIVE ):
            msg.run.purposedLists.purlist[plidx].pur.ptype = 1
        elif( pls.pur.ptype == cvac.PurposeType.NEGATIVE ):
            msg.run.purposedLists.purlist[plidx].pur.ptype = 2
        elif( pls.pur.ptype == cvac.PurposeType.MULTICLASS ):
            msg.run.purposedLists.purlist[plidx].pur.ptype = 3
        elif( pls.pur.ptype == cvac.PurposeType.ANY):
            msg.run.purposedLists.purlist[plidx].pur.ptype = 4
        else:
            print("error: PurposeType not supported, setting to ANY")
            msg.run.purposedLists.purlist[plidx].pur.ptype = 4

        msg.run.purposedLists.purlist[plidx].pur.classID = pls.pur.classID
        # set the PurposedLabelableSeq object's LabelableList fields, for each
        # Labelable object (confidence, lab, sub)
        for laidx, lb in enumerate( pls.labeledArtifacts ):
            # add an Labelable object
            msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable.add()
            # set the Labelable object's confidence, lab, sub fields
            msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].confidence = lb.confidence
            msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].lab.hasLabel = lb.lab.hasLabel
            msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].lab.name = lb.lab.name
            # LabelProperties not set yet
            # msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].lab.properties = lb.lab.properties
            msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].lab.semantix.url = lb.lab.semantix.url
            
            if( type( lb.sub ) == cvac.VideoSubstrate ):
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].vidSub.width = lb.sub.width
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].vidSub.height = lb.sub.height
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].vidSub.videopath.directory.relativePath = lb.sub.videopath.directory.relativePath
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].vidSub.videopath.filename = lb.sub.videopath.filename
                cnt = 0;
                for k, val in zip( lb.sub.framepaths.keys(), lb.sub.framepaths.values() ):
                    msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx] \
                        .vidSub.framepaths.add()
                    msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx] \
                        .vidSub.framepaths[ cnt ].frameNum = k
                    #fpath = cvac.FilePath( directory = cvac.DirectoryPath(
                    #    relativePath = val.directory.relativePath ), filename = val.filename )
                    #msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx] \
                    #    .vidSub.framepaths[ cnt ].framepath = fpath
                    msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx] \
                        .vidSub.framepaths[ cnt ].framepath.directory.relativePath = \
                        val.directory.relativePath
                    msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx] \
                        .vidSub.framepaths[ cnt ].framepath.filename = val.filename
                    cnt = cnt + 1
            if( type( lb.sub ) == cvac.ImageSubstrate ):
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].imgSub.width = lb.sub.width
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].imgSub.height = lb.sub.height
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].imgSub.path.directory.relativePath = lb.sub.path.directory.relativePath
                msg.run.purposedLists.purlist[plidx].labeledArtifacts.labelable[laidx].imgSub.path.filename = lb.sub.path.filename
    
    #   Service Model
    if model != None:
        msg.model.mPath.filename = model.filename
        msg.model.mPath.directory.relativePath = model.directory.relativePath
    
    return msg

def pass_message( msg, msgPath ):
    # write the runset to the agreed-upon in config.service
    if( msg.IsInitialized() ):
        if( os.path.isfile( msgPath ) ):
            print("error: The service message already exists.  Not proceeding "\
                  "because it would destroy the previous message. "\
                  "Recommend calling your service message something else.")
        else:
            f = open( msgPath, "wb" )
            f.write( msg.SerializeToString() )
            f.close()
    else:
        print("error: message not passed because it hasn't been initialized properly")

def retrieve_message( msgPath ):

    protobuf_matlab_bridge_msg = pb.MatlabBridgeMsg()
    try:
        f = open( msgPath, "rb")
        protobuf_matlab_bridge_msg.ParseFromString(f.read())
        f.close()
    
        # remove added file
        os.remove( msgPath )
    except IOError as ioe:
        print("warn: could not obtain result from protobuf message directory: {0}"\
              .format(ioe))
        
    return protobuf_matlab_bridge_msg

def to_CVAC_ResultSet( protobuf_matlab_bridge_msg ):
    rslt_set = []
    for ridx, rslt in enumerate( protobuf_matlab_bridge_msg.res.results.rslt ):
        # set original label for each result
       
        '''
          Note: All the fields should be checked with HasField, but for some reason
          some of the field checks fail with an exception with HasField.  But in the
          case of vidSub and imgSub, if we just check for field not null it does not work
          and we have to use HasField.
        '''
        if (protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.HasField('vidSub')): # VideoSubstrate
            # todo: copy the framepaths
            opath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.videopath.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.videopath.filename )
            osub = cvac.VideoSubstrate( videopath = opath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.height )
        elif (protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.HasField('imgSub') ): # ImageSubstrate
            opath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.path.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.path.filename )
            osub = cvac.ImageSubstrate( path = opath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.height )
        else:
            print "error: unsupported Labelable (original) substrate"
        olab = cvac.Label( hasLabel = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.lab.hasLabel, name = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.lab.name , semantix = cvac.Semantics( url = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.lab.semantix.url ) )
        olabelable = cvac.Labelable( confidence = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.confidence, lab = olab, sub = osub )
        
        # set found label for each result
        #   Labelable case
        flabelable = []
        
        if (protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable ):
            if( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].vidSub ): # VideoSubstrate
                fpath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].vidSub.videopath.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.videopath.filename )
                fsub = cvac.VideoSubstrate( videopath = fpath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.height )
            elif( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].imgSub ): # ImageSubstrate
                fpath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].imgSub.path.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.path.filename )
                fsub = cvac.ImageSubstrate( path = fpath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.height )
            else:
                print "error: unsupported Labelable (found) substrate"
            flab = cvac.Label( hasLabel = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].lab.hasLabel, name = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].lab.name , semantix = cvac.Semantics( url = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].lab.semantix.url ) )
            if( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].vidSub ): # VideoSubstrate
                flabelable = cvac.Labelable( confidence = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].confidence, lab = flab, sub = fsub )
            else: # ImageSubstrate
                flabelable = cvac.Labelable( confidence = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labelable[0].confidence, lab = flab, sub = fsub )
        
        #   LabeledTrack case
        ftlabelable = [] # If we have video tracks
        locLabelable = [] # If we have location Labelabables
        if (protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack ):
 
            if( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].vidSub ): # VideoSubstrate
                ftpath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].vidSub.videopath.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.videopath.filename )
                ftsub = cvac.VideoSubstrate( videopath = ftpath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.height )
            elif( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].imgSub ): # ImageSubstrate
                ftpath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].imgSub.path.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.path.filename )
                ftsub = cvac.ImageSubstrate( path = ftpath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.height )
            else:
                print "error: unsupported LabeledLocation (found) substrate"
            ftlab = cvac.Label( hasLabel = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].lab.hasLabel, name = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].lab.name , semantix = cvac.Semantics( url = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].lab.semantix.url ) )
            track = []
            for fidx, frm in enumerate(protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].keyframesLocations.framelocation):
                vst = cvac.VideoSeekTime(time=frm.frame.time, framecnt=frm.frame.framecnt)
                # '-1' is used to flag locations that are not of a particular type
                if frm.loc.x != -1 and frm.loc.y != -1:
                    pt2d = cvac.Point2D(x=frm.loc.x,y=frm.loc.y)
                elif frm.locPrecise.x != -1 and frm.locPrecise.y != -1:
                    pt2d = cvac.PreciseLocation(centerX=round(frm.locPrecise.x,1), centerY=round(frm.locPrecise.y,1))
                else:
                    print "error: unsupported location type"
                frmLoc = cvac.FrameLocation( frame=vst, loc=pt2d, occluded=frm.occluded,outOfFrame=frm.outOfFrame )
                track.append( frmLoc )
            if ( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].interp == 0 ):
                interpol = cvac.Interpolation.DISCRETE
            elif ( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].interp == 1 ):
                interpol = cvac.Interpolation.LINEAR
            elif ( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].interp == 2 ):
                interpol = cvac.Interpolation.POLYNOMIAL
            else:
                print "error: interpolation type not supported"
            if( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].vidSub ): # VideoSubstrate
                ftlabelable = cvac.LabeledTrack( confidence = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].confidence, lab = ftlab, sub = ftsub, keyframesLocations=track, interp=interpol )
            else: # ImageSubstrate
                ftlabelable = cvac.LabeledTrack( confidence = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledTrack[0].confidence, lab = ftlab, sub = ftsub, keyframesLocations=track, interp=interpol )
        elif (protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation ):
            if( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].vidSub ): # VideoSubstrate
                ftpath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].vidSub.videopath.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.videopath.filename )
                ftsub = cvac.VideoSubstrate( videopath = ftpath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.vidSub.height )
            elif( protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].imgSub ): # ImageSubstrate
                ftpath = cvac.FilePath( directory = cvac.DirectoryPath( relativePath = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].imgSub.path.directory.relativePath ), filename = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.path.filename )
                ftsub = cvac.ImageSubstrate( path = ftpath, width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.width, height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].original.imgSub.height )
            else:
                print "error: unsupported LabeledTrack (found) substrate"
            hasLabel = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].lab.hasLabel
            name = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].lab.name 
            semantix = cvac.Semantics( url = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[0].lab.semantix.url )
            ftlab = cvac.Label( hasLabel = hasLabel, name = name , semantix = semantix )
            for lidx, loc in enumerate(protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation):
                ftbox = cvac.BBox()   
                ftbox.x = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[lidx].loc.x
                ftbox.y = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[lidx].loc.y
                ftbox.width = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[lidx].loc.width
                ftbox.height = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[lidx].loc.height
                confidence = protobuf_matlab_bridge_msg.res.results.rslt[ridx].foundLabels.labeledLocation[lidx].confidence
                locLabelable.append(cvac.LabeledLocation( confidence = confidence, lab = ftlab, sub = ftsub, loc = ftbox ))
        # append result
        if flabelable and ftlabelable:
            rslt_set.append( cvac.Result( olabelable, [ flabelable, ftlabelable ] ) )
        elif flabelable:
            rslt_set.append( cvac.Result( olabelable, [ flabelable ] ) )
        elif ftlabelable:
            rslt_set.append( cvac.Result( olabelable, [ ftlabelable ] ) )
        elif locLabelable:
            rslt_set.append( cvac.Result(olabelable, locLabelable))
        else:
            print "debug: didn't find a label, so setting an empty one"
            rslt_set.append( cvac.Result( olabelable, [ cvac.Labelable() ] ) )
    
    resultset = cvac.ResultSet( rslt_set )
    
    return resultset

class MatlabBridgeTrainerI(cvac.DetectorTrainer, threading.Thread):
    def __init__(self, communicator, service, entryFunc, msgPath, executable ):
        threading.Thread.__init__(self)
        self._communicator = communicator
        self._destroy = False
        self._clients = []
        self._cond = threading.Condition()
        self.runSetFromClient = None
        self.propertiesFromClient = None
        self.timeStamp = None
        self.CVAC_DataDir = None
        self.ConnectionName = "localhost"
        self.zipHnd = None
        self.matlabService = service
        self.matlabEntryFunc = entryFunc
        self.matlabMsgPath = msgPath
        self.matlabExecutable = executable
    
    def destroy(self):
        self._cond.acquire()
        
        #print("debug: stopping service: {0}".format( self.matlabService ))
        self._destroy = True
        
        try:
            self._cond.notify()
        finally:
            self._cond.release()
        
        self.join()
    
    def getTrainerProperties(self, current=None):
        #TODO get the real detector properties but for now return an empty one.
        props = cvac.TrainerProperties()
        return props
    
    def process(self, client, run, props, current=None):
        self._cond.acquire()
        _callback = cvac.TrainerCallbackHandlerPrx.uncheckedCast(current.con.createProxy(client).ice_oneway())
        self._clients.append(_callback)
        
        self.CVAC_DataDir = self._communicator.getProperties().getProperty( "CVAC.DataDir" )
        self.runSetFromClient = run
        self.propertiesFromClient = props
        self.timeStamp = datetime.datetime.fromtimestamp(time.time()).strftime('%Y_%m_%d_%H_%M_%S')
        
        self._cond.wait()
        self._cond.release()
    
    def run(self):
        #print("debug: {0} waiting for messages".format( self.matlabService ))
        while True:
            self._cond.acquire()
            try:
                self._cond.wait(0.01)  #sec
                if self._destroy:
                    break
                clients = self._clients[:]
            finally:
                self._cond.release()
            
            if len(clients) > 0:
                for p in clients:
                    print("info: got connection")
                    tsize = len(self.runSetFromClient.purposedLists)
                    if tsize != 2:
                        print("Warning: Number of RunSet Purposes is {0}".format(tsize))
                    
                    # construct the training message to pass to Matlab
                    msg = to_protobuf( self.runSetFromClient, self.propertiesFromClient )
                    
                    # pass the message to Matlab
                    pass_message( msg, self.matlabMsgPath )
                    print( "debug: {0} service message passed. MATLAB output to follow"\
                           .format( self.matlabService ))
                    
                    # start Matlab process
                    cmd = "msg_path='{0}'; matlab_bridge_dir='{1}'; easy_data_dir='{2}'; run('{3}'); exit"\
                        .format(self.matlabMsgPath, thisPath, dataPath, self.matlabEntryFunc)
                    
                    #   get OS (Windows or OSX)
                    op_sys = sys.platform
                    if op_sys == 'darwin':
                        print("----------------------------------------------------------------------")
                        process_success = call( [ self.matlabExecutable, "-nodesktop",
                                                  "-nosplash", "-nodisplay", "-r", cmd ] )
                        print("----------------------------------------------------------------------")
                    elif op_sys == 'linux2':
                        print("----------------------------------------------------------------------")
                        process_success = call( [ self.matlabExecutable, "-nodesktop",
                                                  "-nosplash", "-nodisplay", "-r", cmd ] )
                        print("----------------------------------------------------------------------")
                    elif op_sys == 'win32':
                        # TODO: windows commands
                        print("----------------------------------------------------------------------") 
                        process_success = call( [ self.matlabExecutable, "-nodesktop",
                                                 "-nosplash", "-nodisplay", "-r", cmd ] )
                        # on Windows, write a semaphore file that is waited on below;
                        # this is because the Windows Matlab executable starts another process and
                        # exits right away.
                        while not os.path.isfile( self.matlabMsgPath+'.done' ):
                            time.sleep(0.1) # 0.1 seconds
                        os.remove( self.matlabMsgPath+'.done' )
                        print("----------------------------------------------------------------------")
                    else:
                        # TODO: other operating systems
                        print("error: Operating system not supported")
                    
                    # retrieve the matlab bridge message
                    if process_success == 0:
                        protobuf_matlab_bridge_msg = retrieve_message( self.matlabMsgPath )
                    else:
                        #TODO: error checking
                        print("The system call to MATLAB, or the MATLAB process itself, failed")
                    
                    # report the result
                    model = easy.getCvacPath( protobuf_matlab_bridge_msg.model.mPath.directory.relativePath + '/' + protobuf_matlab_bridge_msg.model.mPath.filename )
                    p.createdDetector( model )
                    p.message(2,"The trained model has been saved to " + model.directory.relativePath + "/" + model.filename + '\n' )
                
                    self._cond.acquire()
                    try:
                        self._clients.remove(p)
                        self._cond.notify()
                    finally:
                        self._cond.release()


class MatlabBridgeDetectorI(cvac.Detector, threading.Thread):
    def __init__(self, communicator, service, entryFunc, msgPath, executable):
        threading.Thread.__init__(self)
        self._communicator = communicator
        self._destroy = False
        self._clients = []
        self._cond = threading.Condition()
        self.mListTestFile=[]
        self.CVAC_DataDir = None
        self.runSetFromClient = None
        self.detectorDataFromClient = None
        self.propertiesFromClient = None
        self.timeStamp = None
        self.ConnectionName = "localhost"
        self.matlabService = service
        self.matlabEntryFunc = entryFunc
        self.matlabMsgPath = msgPath
        self.matlabExecutable = executable
    
    def destroy(self):
        self._cond.acquire()
        
        #print("debug: stopping service: {0}".format( self.matlabService ))
        self._destroy = True
        
        try:
            self._cond.notify()
        finally:
            self._cond.release()
        
        self.join()
    
    def process(self, client, runset, data, props, current=None):
        self._cond.acquire()
        _callback = cvac.DetectorCallbackHandlerPrx.uncheckedCast(current.con.createProxy(client).ice_oneway())
        self._clients.append(_callback)
        self.CVAC_DataDir = self._communicator.getProperties().getProperty( "CVAC.DataDir" )
        self.runSetFromClient = runset
        self.detectorDataFromClient = data
        self.propertiesFromClient = props
        self.timeStamp = datetime.datetime.fromtimestamp(time.time()).strftime('%Y_%m_%d_%H_%M_%S')
        
        self._cond.wait()
        self._cond.release()
    
    def getDetectorProperties(self, current=None):
        #self.dprops.writeProps()
        prop = cvac.DetectorProperties()
        #self.writeProps(prop)
        return prop
    
    def run(self):
        #print("debug: {0} is waiting for messages".format( self.matlabService ))
        while True:
            self._cond.acquire()
            try:
                self._cond.wait(0.01)  #sec
                if self._destroy:
                    break
                clients = self._clients[:]
            finally:
                self._cond.release()
            
            if len(clients) > 0:
                for p in clients:
                    print("info: got connection")
                    # construct the message to pass to Matlab
                    msg = to_protobuf( self.runSetFromClient, self.propertiesFromClient, model=self.detectorDataFromClient )
                    
                    # pass the message to Matlab
                    pass_message( msg, self.matlabMsgPath )
                    print( "debug: {0} service message passed. MATLAB output to follow"\
                            .format( self.matlabService ) )
                    
                    # start Matlab process
                    cmd = "msg_path='{0}'; matlab_bridge_dir='{1}'; easy_data_dir='{2}'; run('{3}'); exit"\
                        .format(self.matlabMsgPath, thisPath, dataPath, self.matlabEntryFunc)
                    
                    #   get OS (Windows or OSX)
                    op_sys = sys.platform
                    if op_sys == 'darwin':
                        print("----------------------------------------------------------------------")
                        process_success = call( [ self.matlabExecutable, "-nodesktop",
                                                 "-nosplash", "-nodisplay", "-r", cmd ] )
                        print("----------------------------------------------------------------------")
                    elif op_sys == 'win32':
                        # TODO: windows commands
                        print("----------------------------------------------------------------------")
                        process_success = call( [ self.matlabExecutable, "-nodesktop",
                                                 "-nosplash", "-automation", "-r", cmd ] )
                        # on Windows, write a semaphore file that is waited on below;
                        # this is because the Windows Matlab executable starts another process and
                        # exits right away.
                        while not os.path.isfile( self.matlabMsgPath+'.done' ):
                            time.sleep(0.1) # 0.1 seconds
                        os.remove( self.matlabMsgPath+'.done' )
                        print("----------------------------------------------------------------------")
                    else:
                        # TODO: other operating systems
                        print("error: Operating system not supported")
                
                    # retrieve the matlab bridge message
                    if process_success == 0:
                        protobuf_matlab_bridge_msg = retrieve_message( self.matlabMsgPath )
                       
                    else:
                        #TODO: error checking
                        print("The system call to MATLAB, or the MATLAB process itself, failed")
                    
                    # convert the matlab bridge message results to CVAC ResultSet
                    res = to_CVAC_ResultSet( protobuf_matlab_bridge_msg )
                    
                    p.foundNewResults(res)
                    
                    self._cond.acquire()
                    try:
                        self._clients.remove(p)
                        self._cond.notify()
                    finally:
                        self._cond.release()

class Server(Ice.Application):
    def run(self, args):
        service_name = args[ 1 ]
        #print "debug: starting Matlab bridge to {0} service".format( service_name )

        # Parse config.services
        service_definition = matlab_bridge_service_parser( "config.service", service_name )

        try:
            adapter = self.communicator().createObjectAdapter( service_name )
        except Ice.SocketException as ise:
            print("error: while starting {0} service:".format(service_name))
            raise ise
        
        if service_definition[ 'MatlabServiceType' ] == 'DetectorTrainer':
            sender = MatlabBridgeTrainerI( self.communicator(), service_name,
                                           service_definition[ 'MatlabServiceEntryFunction' ],
                                           service_definition[ 'MatlabServiceMsgPath' ],
                                           service_definition[ 'MatlabExecutable' ] )
        elif service_definition[ 'MatlabServiceType' ] == 'Detector':
            sender = MatlabBridgeDetectorI( self.communicator(), service_name,
                                            service_definition[ 'MatlabServiceEntryFunction' ],
                                            service_definition[ 'MatlabServiceMsgPath' ],
                                            service_definition[ 'MatlabExecutable' ] )
        else:
            print("error: Matlab Service Type {0} not supported"\
                .format( service_definition[ 'MatlabServiceType' ] ))
        adapter.add( sender, self.communicator().stringToIdentity( service_name ) )
        
        adapter.activate()
        
        sender.start()
        print("info: service started: {0}".format( service_name ))

        try:
            self.communicator().waitForShutdown()
        finally:
            sender.destroy()
        
        print("info: service stopped: {0}".format( service_name ))
        return 0

def matlab_bridge_service_parser( config_service_file, service_name ):
    '''
        Find all the lines of the format service_namex.Something=AValue
        (yes the x has to be there). Return a dictionary with
        the Something string as the keys and the AValue as values.
        '''
    # read the config.service file
    lines = open( config_service_file ).readlines()
    
    # remove comments
    lines = [ line.strip() for line in lines if line.startswith(service_name+"x.") ]
    lines = [ line[len(service_name+"x."):] for line in lines ]
    tuples = [ line.split("=") for line in lines ]
    dict = {}
    for t in tuples:
        dict[ t[ 0 ] ] = t[ 1 ]
    return dict

# Matlab Bridge entry
if len( sys.argv ) != 2:
    print "error: need name of service to bridge to as argument"
    sys.exit(-1)
#print("debug: MatlabBridge invoked for: {0}".format( sys.argv[ 1 ] ) )

# start up the service
app = Server()
sys.exit( app.main( sys.argv, "config.service" ) )
