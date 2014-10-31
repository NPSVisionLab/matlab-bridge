'''
Easy!  mini tutorial
Kalman tracker via Matlab Bridge
matz 10/2014
'''

import easy

#
# create a test set as in the Matlab sample at
# http://www.mathworks.com/help/vision/ug/object-tracking.html
# You need to have the Matlab vision toolbox installed.  The
# singleball.avi movie is here:
# YourMatlabProgramPath/toolbox/vision/visiondemos/singleball.avi
#


# runset = easy.createRunSet( "singleball.avi")

# Optionally, specify a folder that contains 1-all of the videos frames as images
runset = easy.createRunSet( "singleball.avi", framesFolder="singleball" )

#
# evaluate your tracking algorithm with a common match scoring method
#
tracker = easy.getDetector( "KalmanTracker:default -p 20133" )
results = easy.detect( tracker, None, runset )
easy.printResults( results )
