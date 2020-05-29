import MotionEstimation, CreateRegisteredImages, CreateRegisteredSequences
import CUDABatchProcessorToolBag
import cPickle

def callDeMotionDirectly(dmp_ffname):
    fid = open(dmp_ffname, 'r')
    pick = cPickle.load(fid)
    fid.close()

    toolbag = CUDABatchProcessorToolBag.CUDABatchProcessorToolBag()
