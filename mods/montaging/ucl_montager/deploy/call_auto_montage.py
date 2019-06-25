"""This is a temporary solution to what is probably a simple problem of not being able to import the custom classes and
functions"""
# Builtin imports
from scipy.sparse import csgraph
from scipy import ndimage
from PIL import Image
from time import time
from threading import Thread, Event
import os
import sys
import getopt
import queue
import cv2
import xlrd
import re
import numpy as np

# Custom imports
'''
from . import transformation_finder
from . import montage_builder
from . import input_pipeline
from . import script_maker
'''


# Defaults
modScheme = {
    'confocal': 'confocal',
    'split':    'split_det',
    'avg':      'avg'}
imgPath = ''
posPath = ''
posFname = ''
eyeOX = ''
outPath = ''

# Input argument syntax
argList = ["imgPath=", "posPath=", "posFname=", "eyeOX=", "outPath="]

try:
    opts, args = getopt.getopt(sys.argv[1:], '', argList)
    #print opts
    #print args
except getopt.GetoptError:
    print('Failure')
    print(getopt.GetoptError.message)
    sys.exit(2)
for opt, arg in opts:
    if opt in '--imgPath':
        imgPath = arg
    elif opt in '--posPath':
        posPath = arg
    elif opt in '--posFname':
        posFname = arg
    elif opt in '--eyeOX':
        eyeOX = arg
    elif opt in '--outPath':
        outPath = arg

# Construct position file full file name
posFFname = os.path.join(posPath, posFname)

# todo: figure out how to import these functions instead of having them all in one script


def create_preferences(jsfile):
    jsfile.write("""
app.preferences.rulerUnits = Units.PIXELS
app.preferences.typeUnits = TypeUnits.PIXELS
app.displayDialogs = DialogModes.NO
var color = new SolidColor()
color.gray.gray = 100
""")


def create_function(jsfile):
    jsfile.write("""
var AVG = 0
var SPLIT = 1
var CONF = 2
var names = ["avg", "split_det", "confocal"]

function addLinkedImage(confocal_fname, dx, dy, h, w, doc) {

	var docRef = docs[doc]
	var split_fname = confocal_fname.replace(names[CONF], names[SPLIT])
	var avg_fname = confocal_fname.replace(names[CONF], names[AVG])

	var file_names = [avg_fname, split_fname, confocal_fname]

	// input the three image types into there layersets
	for (var imageType = 0; imageType < 3; imageType++){
		// open new document with just the image so we can duplicate to montage
		var img = new File(file_names[imageType]);
		var opened = open(img);
		opened.resizeImage(w, h)
        opened.resizeCanvas(w, h)
		var pSourceDocument = app.activeDocument;
		pSourceDocument.artLayers[0].duplicate(docRef);
		pSourceDocument.close(SaveOptions.DONOTSAVECHANGES)

		// get the layer in the montage document
		var layerInOrig = docRef.artLayers[0]
		var image_name = file_names[imageType].split('\\\\')
		layerInOrig.name = image_name[image_name.length - 1]
		layerInOrig.move(docRef.layerSets.getByName(names[imageType]),  ElementPlacement.INSIDE)
	}

	// link the three images
	for (var imageType = 0; imageType < 2; imageType++) {
		var layersetOne = docRef.layerSets.getByName(names[imageType])
		var layersetTwo = docRef.layerSets.getByName(names[imageType + 1])
		var image_one_name = file_names[imageType].split('\\\\')
		var artLayerOne = layersetOne.artLayers.getByName(image_one_name[image_one_name.length - 1])
		var image_two_name = file_names[imageType + 1].split('\\\\')
		var artLayerTwo = layersetTwo.artLayers.getByName(image_two_name[image_two_name.length - 1])

		artLayerOne.link(artLayerTwo)
		layersetOne.visible = false
	}

	// add resizing to canvas
	var confocal_layer_set = docRef.layerSets.getByName(names[CONF])
	var confocal_name = file_names[CONF].split('\\\\')
	var confocal_image_layer = confocal_layer_set.artLayers.getByName(confocal_name[confocal_name.length - 1])
	confocal_image_layer.translate(dx, dy)
}

for (var disjoint = 0; disjoint<docs.length; disjoint++){
	var translations = data[disjoint]
	app.activeDocument = docs[disjoint]
	for (var i = 0; i<translations.length; i++) {
		var d = translations[i]
		var confocal_name = d[0]
		var ty = d[1]
		var tx = d[2]
		var h = d[3]
		var w = d[4]
		addLinkedImage(confocal_name, ty, tx, h, w, disjoint)
	}
	docs[disjoint].revealAll()
}
""")


def get_doc_add_layerset(doc):
    return """
app.activeDocument = docs[""" + str(doc) + """]
app.activeDocument.selection.fill(color, ColorBlendMode.NORMAL, 100, false)
var docRef = docs[""" + str(doc) + """]
var confocal = docRef.layerSets.add()
confocal.name = "confocal"
var split = docRef.layerSets.add()
split.name = "split_det"
var avg = docRef.layerSets.add()
avg.name = "avg"
"""


def create_doc(doc):
    return 'app.documents.add(10000, 10000, 72, "montage' + str(doc) + '", NewDocumentMode.GRAYSCALE)'


def create_transformations(jsfile, disjoint_montage):
    for disjoint in range(len(disjoint_montage)):
        jsfile.write('var data' + str(disjoint) + ' = [')

        trans_for_join = []
        for transformation in disjoint_montage[disjoint]:
            confocal_name = transformation['confocal']
            ty = float(transformation['transy'])
            tx = float(transformation['transx'])

            # if global_ref set its height
            if tx == 0.0 and ty == 0.0:
                global_height = int(transformation['h'])
                global_width = int(transformation['w'])

            height = int(transformation['h'])
            width = int(transformation['w'])
            trans_for_join.append(
                str([
                    confocal_name,
                    float(ty) + (width - global_width) / 2.,
                    float(tx) + (height - global_height) / 2., height, width]))

        data = ','.join(trans_for_join)
        jsfile.write(data)
        jsfile.write(']\n')
    return len(disjoint_montage)


def create_array_of_data(jsfile, chunks):
    jsfile.write('var data = [')
    montage_js = []
    for disjoint_montage in range(chunks):
        montage_js.append('data' + str(disjoint_montage))
    montage_js_as_string = ','.join(montage_js)
    jsfile.write(montage_js_as_string)
    jsfile.write(']\n')


def create_doc_array(jsfile, chunks):
    jsfile.write('var docs = [')
    docs_js = []
    for doc in range(chunks):
        docs_js.append(create_doc(doc))
    docs_js_as_string = ','.join(docs_js)
    jsfile.write(docs_js_as_string)
    jsfile.write(']\n')


def create_layer_sets(jsfile, chunks):
    for doc in range(chunks):
        jsfile.write(get_doc_add_layerset(doc))


def write_photoshop_script(disjoint_montages, photoshop_directory, name=None):
    fname = 'create_recent_montage.jsx' if name is None else name + '.jsx'
    with open(os.path.join(photoshop_directory, fname), 'w') as jsfile:
        # preferences, units etc
        create_preferences(jsfile)

        # creating arrays with the translations and file names
        # will have to find the right folder
        chunks = create_transformations(jsfile, disjoint_montages)

        # puts the previous arrays into a single array
        create_array_of_data(jsfile, chunks)

        # creates required number of docs
        create_doc_array(jsfile, chunks)

        # add the layersets to these docs
        create_layer_sets(jsfile, chunks)

        # write the ending script which has the function
        create_function(jsfile)


class MontageBuilder:
    COMPONENT_BUILT = -1

    def __init__(self, transformation_finder, evaluate=False):
        self.matched = transformation_finder.matched
        self.translation = transformation_finder.translations
        self.global_translation = np.zeros_like(self.translation)
        self.mm_images = transformation_finder.mmList
        self._num_im = len(self.mm_images)

    def connnected_components(self, ):
        graph = np.zeros([self._num_im, self._num_im], dtype=np.bool)
        for i in range(self.matched.shape[0]):
            graph[i, self.matched[i]] = True
        n, labels = csgraph.connected_components(graph, directed=False, return_labels=True)
        return n, labels

    def construct_all_montages(self, ):
        number_components, labels = self.connnected_components()
        disjoint_montages = []

        for component in range(number_components):
            indices = np.argwhere(labels == component)
            transformations, indices = self.construct_component(indices, component)
            disjoint_montages.append((transformations, indices))
        return disjoint_montages

    def _get_pairwise(self, indices):
        # get all pairwise connections
        connected_to = dict()
        original_image = None
        for dst_img in indices:
            connected_to[dst_img] = []
            for src_img in indices:

                # find images which map to dst_img
                if self.matched[src_img] == dst_img:
                    connected_to[dst_img].append(src_img)

                # get fixed image
                if self.matched[dst_img] == dst_img:
                    original_image = dst_img

            # delete dict entry if empty
            if len(connected_to[dst_img]) == 0:
                connected_to.pop(dst_img, None)

        return connected_to, original_image

    def _choose_next_dst(self, current_dst, connected_to):
        for key in connected_to.keys():
            if key == current_dst:
                continue
            if key in connected_to[current_dst]:
                return key, True
        return None, False

    def update_local_transformation(self, directly_connected, global_ref):

        def recursiveTranslation(reference, global_trans):

            # ending condition, which will always be met
            # as this is a connected component
            if reference in directly_connected[global_ref]:
                return global_trans + self.translation[reference, global_ref]

            # find any element which contains local ref as src
            # and align the ref to this, then look for how to
            # align the new ref to global ref

            for ref in directly_connected:
                src_ims = directly_connected[ref]
                if reference in src_ims:
                    global_trans += self.translation[reference, ref]
                    global_trans = recursiveTranslation(ref, global_trans)
                    break
            return global_trans

        global_trans_dict = dict()
        for ref in directly_connected:
            src_ims = directly_connected[ref]
            global_trans = np.array([0., 0.])
            global_trans = recursiveTranslation(ref, global_trans)
            global_trans_dict[ref] = global_trans

        for ref in directly_connected:
            src_ims = directly_connected[ref]
            for src in src_ims:
                self.translation[src, ref] += global_trans_dict[ref]

    def get_transformation(self, indices):
        transformations = []
        for src_id in indices:
            row = dict()

            # file names
            confocal = self.mm_images[src_id].get_confocal_name()
            split = self.mm_images[src_id].get_split_name()
            avg = self.mm_images[src_id].get_avg_name()

            # translation
            dst_id = self.matched[src_id]
            t = self.translation[src_id, dst_id]
            y, x = t[0, 0], t[0, 1]

            # put into dict and write
            row['confocal'] = confocal
            row['split'] = split
            row['avg'] = avg
            row['transy'] = y
            row['transx'] = x
            row['h'] = self.mm_images[src_id].get_confocal().shape[0]
            row['w'] = self.mm_images[src_id].get_confocal().shape[1]

            transformations.append(row)
        return transformations

    def construct_component(self, indices, idx):
        # make into iterable list
        indices = list(indices.ravel())

        # get first pairwise connections
        directly_connected, global_ref = self._get_pairwise(indices)

        # construct gobal transformation
        self.update_local_transformation(directly_connected, global_ref)

        # write transformation to file
        transformations = self.get_transformation(indices)

        return transformations, indices

    def transform_box(self, src, dst, box):
        transform = self.translation[src, dst]
        return box + transform

    def _get_global_box(self, indices):
        """bounding box size for a chunk after making transformation global"""
        global_x_min = np.infty
        global_x_max = -np.infty
        global_y_min = np.infty
        global_y_max = -np.infty
        for src_id in indices:
            # get vals
            src_img = self.mm_images[src_id]
            dst_id = self.matched[src_id]
            h, w = src_img.get_confocal().shape

            # transform box and find values
            bounding_box = np.array([[0, 0], [0, h - 1], [w - 1, 0], [w - 1, h - 1]])
            transfor_box = self.transform_box(src_id, dst_id, bounding_box)
            x_min, y_min = np.min(transfor_box, axis=0)
            x_max, y_max = np.max(transfor_box, axis=0)

            # update global box
            global_x_min = x_min if x_min < global_x_min else global_x_min
            global_y_min = y_min if y_min < global_y_min else global_y_min
            global_x_max = x_max if x_max > global_x_max else global_x_max
            global_y_max = y_max if y_max > global_y_max else global_y_max

        return int(global_x_min), int(global_x_max), int(global_y_min), int(global_y_max)

    def setup_folders(self, indice_list, subject):
        eval_directory = '/media/benjamin/Seagate Backup Plus Drive/montageWithPiece'
        directory = os.path.join(eval_directory, subject)
        os.makedirs(directory)

        for idx, val in enumerate(indice_list):
            for modality in ['confocal', 'split', 'avg']:
                new_dir = os.path.join(directory, str(idx), modality)
                os.makedirs(new_dir)

    def build_fname(self, subject, mntge_type, idx, fname):
        # build save path
        eval_directory = '/media/benjamin/Seagate Backup Plus Drive/montageWithPiece'
        save_path = os.path.join(eval_directory, subject, str(idx), mntge_type, fname)
        return save_path

    def saveImWithAlpha(self, im, alpha, subject, mntge_type, idx, fname):

        fname = fname.split('/')[-1]
        save_path = self.build_fname(subject, mntge_type, idx, fname)

        # convert image to pil LA image
        im = np.uint8(im)
        im = Image.fromarray(im)
        im = im.convert('LA')

        # convert alpha mask to L
        alpha = np.uint8(alpha * 255)
        alpha_im = Image.fromarray(alpha)
        alpha_im = alpha_im.convert('L')

        # build and save
        im.putalpha(alpha_im)
        im.save(save_path)

    def save_montage(self, montage, subject, mntge_type, idx):
        save_path = self.build_fname(subject, mntge_type, idx, 'full.tiff')

        # convert image to pil LA image
        montage = np.uint8(montage)
        im = Image.fromarray(montage)
        im.save(save_path)

    def save_pieces(self, indices_list, subject):

        # setup all folders for the subject montage
        self.setup_folders(indices_list, subject)

        for idx, indices in enumerate(indices_list):

            # build global coordinates
            gx_min, gx_max, gy_min, gy_max = self._get_global_box(indices)
            grid_x, grid_y = np.meshgrid(
                np.arange(gx_min, gx_max),
                np.arange(gy_min, gy_max),
            )
            montage = np.zeros([gy_max - gy_min, gx_max - gx_min])

            for mntge_type in ['confocal', 'split', 'avg']:

                for src_id in indices:
                    src_img, src_name = self.mm_images[src_id].get_image_and_name(mntge_type)
                    dst_id = self.matched[src_id]

                    # mask to form alpha channel
                    src_mask = np.ones(src_img.shape)

                    # actual translation
                    t = self.translation[src_id, dst_id]

                    # move image and mask
                    warped_image = ndimage.map_coordinates(
                        src_img,
                        [grid_y - t[0, 1], grid_x - t[0, 0]],
                        order=3,
                        cval=0.0, )

                    warped_mask = ndimage.map_coordinates(
                        src_mask,
                        [grid_y - t[0, 1], grid_x - t[0, 0]],
                        order=1,
                        cval=0.0, )

                    self.saveImWithAlpha(warped_image, warped_mask, subject, mntge_type, idx, src_name)
                    montage = np.where(warped_mask > 0, warped_image, montage)

                self.save_montage(montage, subject, mntge_type, idx)


def load_from_fname(fname, resize):
    """
        loads image and gets rid of any extra unused dimensions
        as they smeetimes save as rgb accidently
    """
    im = Image.open(fname)
    if len(im.split()) > 1:
        im = im.split()[0]
    im = np.array(im.getdata(), dtype = np.uint8).reshape(im.size[1], im.size[0])
    if resize is not None:
        h = int(im.shape[0] * resize)
        w = int(im.shape[1] * resize)
        im = cv2.resize(im, (w, h))
    return im


# Print iterations progress
def printProgressBar (iteration, total, prefix = '', suffix = '', decimals = 1, length = 100, fill = '*'):
    """
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print('\r%s |%s| %s%% %s' % (prefix, bar, percent, suffix), end='\r')
    # Print New Line on Complete
    if iteration == total:
        print()


class MultiModalImage:
    index = {'split':0, 'confocal':1, 'avg':2}

    def __init__(self, confocal, split, avg, nominal_position, fov, resize):
        """
            store names, nominal position and images as a single
            numpy tensor [height, width, channel]
        """
        self.fov = fov
        self.split_fname = split
        self.confocal_fname = confocal
        self.avg_fname = avg
        split = load_from_fname(split, resize)
        confocal = load_from_fname(confocal, resize)
        avg = load_from_fname(avg, resize)
        self.multimodal_im = np.stack([split, confocal, avg], axis=2)
        self.nominal_position = nominal_position

        self.keypoints = {'split':None, 'confocal':None, 'avg':None}
        self.descriptors = {'split':None, 'confocal':None, 'avg':None}

    def get_confocal(self,):
        return self.multimodal_im[:,:,MultiModalImage.index['confocal']]

    def get_split(self,):
        return self.multimodal_im[:,:,MultiModalImage.index['split']]

    def get_avg(self,):
        return self.multimodal_im[:,:,MultiModalImage.index['avg']]

    def get_split_name(self,):
        return self.split_fname

    def get_confocal_name(self,):
        return self.confocal_fname

    def get_avg_name(self,):
        return self.avg_fname

    def get_nominal(self,):
        return self.nominal_position

    def get_image_and_name(self, mntge_type):
        if mntge_type == 'confocal':
            src_img = self.get_confocal()
            src_name = self.get_confocal_name()
        elif mntge_type == 'split':
            src_img = self.get_split()
            src_name = self.get_split_name()
        elif mntge_type == 'avg':
            src_img = self.get_avg()
            src_name = self.get_avg_name()
        else:
            raise ValueError('No type named {}'.format(mntge_type))
        return src_img, src_name

    def calculate_orb(self,):
        """calculate and set the descriptors"""
        for modality in self.keypoints.keys():
            image = self.multimodal_im[:,:,MultiModalImage.index[modality]]
            kps, desc = compute_kps_desc(image)
            self.keypoints[modality] = kps
            self.descriptors[modality] = desc


def compute_kps_desc(image):
    orb = cv2.ORB_create(
        nfeatures=5000,
    )
    kp, des = orb.detectAndCompute(image, None)
    return kp, des


def match_desc(desc1, desc2, key):
    """return the matches which pass the ratio test"""

    # sometimes there are noe descriptors
    if desc1 is None or desc2 is None:
        return [], key

    FLANN_INDEX_LSH = 6
    index_params = dict(algorithm=FLANN_INDEX_LSH,
                        table_number=6,  # 12
                        key_size=12,  # 20
                        multi_probe_level=1)  # 2
    search_params = dict()  # or pass empty dictionary

    flann = cv2.FlannBasedMatcher(index_params, search_params)
    matches = flann.knnMatch(desc1, desc2, k=2)

    good_matches = []

    for best_two in matches:
        if len(best_two) > 1:
            m, n = best_two
            if m.distance < 0.9 * n.distance:
                good_matches.append(m)

    return good_matches, key


def ransac(src, dst, iterations=1000, threshold=10.0):
    """ransac written in python as nothing in opencv for just translations"""
    iterations = iterations if iterations < src.shape[0] else src.shape[0]

    # potential transformations given by some row
    rows = np.arange(src.shape[0])
    np.random.shuffle(rows)
    rows = rows[:iterations]

    # all potential translations
    translations = dst[rows, :] - src[rows, :]

    # src = matched_points x dimensions
    # after_tile = num_translations x matched x dimensions
    # translations = num_translations x dimension
    # y = np.tile(src, (iterations, 1, 1)) + translations[:, None, :]
    y = src[None, :, :] + translations[:, None, :]

    # y = trans x matched x dim
    error = (y - dst[None, :, :])
    error *= error
    l2 = np.sum(error, axis=2)

    num_inliers = np.sum(l2 < threshold, axis=1)
    best = np.argmax(num_inliers)

    return num_inliers[best], translations[best]


class TransformationFinder:
    UNMATCHED = -1
    nom_thresh = 7.
    auto_accept = 50
    avg = 0.
    n = 0.
    """
        Take list of MultiModalImage objects. Compute all the keypoints
        and descriptors. Then try to match these images, thus constructing
        pairwise registrations.
    """

    def __init__(self, mmList):
        self.mmList = mmList
        self._num = len(mmList)

        # a dictionary of
        # dict[image_id] = sorted_list_of_closest_images
        self.closest_mm_images = self.build_closest()

        # space to store translations, numbers of matches and if we have
        # already calculated some registration
        self.translations = np.zeros([self._num, self._num, 2])
        self.inlier_matches = np.zeros([self._num, self._num], dtype=np.int16)
        self.have_computed = np.zeros([self._num, self._num], dtype=np.bool)
        self.min_inliers = 10
        self.matched = None

    def build_closest(self, ):
        """
            find images closest to each image, below a threshold distance.
            Save this as a sorted list, with the closest first.

            output:
                dict[image_id] = sorted_list_of_images
        """

        closest_to = dict()

        # for each image_id
        for src in range(self._num):

            # current image and its location
            src_im = self.mmList[src]
            src_pos = src_im.get_nominal()

            # save all the close enough images here
            dsts = []
            for dst in range(self._num):

                # ignore if same image
                if dst == src:
                    continue

                # distance between src and dst
                dst_im = self.mmList[dst]
                dst_pos = dst_im.get_nominal()
                distance = (src_pos - dst_pos)
                distance = (distance * distance).sum()

                # save if within threshold
                if distance < TransformationFinder.nom_thresh:
                    dsts.append((dst, distance))

            # for current image sort the closest images
            # based on distance
            dsts.sort(key=lambda x: x[1])
            dsts = list(map(lambda x: x[0], dsts))
            closest_to[src] = dsts
        return closest_to

    def compute_kps_desc(self, ):
        for mm in self.mmList:
            mm.calculate_orb()

    def match_two_images(self, mm1, mm2):
        """given two MMImages match the descriptors for each channel individually"""
        matches = dict(split=[], confocal=[], avg=[])
        for key in MultiModalImage.index.keys():
            modality_matches, key = match_desc(mm1.descriptors[key], mm2.descriptors[key], key)
            matches[key] += modality_matches
        return matches

    def get_all_matches(self, i, j):
        """
            combines all matches for each channel into two
            keypoint point clouds, rather than 6
        """
        mm1 = self.mmList[i]
        mm2 = self.mmList[j]
        matches = self.match_two_images(mm1, mm2)

        srcpts = []
        dstpts = []
        for key in MultiModalImage.index.keys():
            kp1 = mm1.keypoints[key]
            kp2 = mm2.keypoints[key]
            ms = matches[key]
            src_pts = np.float32([kp1[m.queryIdx].pt for m in ms]).reshape(-1, 2)
            dst_pts = np.float32([kp2[m.trainIdx].pt for m in ms]).reshape(-1, 2)
            srcpts.append(src_pts)
            dstpts.append(dst_pts)

        src_pts = np.concatenate(srcpts, axis=0)
        dst_pts = np.concatenate(dstpts, axis=0)

        return src_pts, dst_pts

    def compute_translation(self, i, j):
        src, dst = self.get_all_matches(i, j)
        inliers, translation = ransac(src, dst)

        self.translations[i, j, :] = translation
        self.inlier_matches[i, j] = inliers
        self.have_computed[i, j] = True

    def get_translation(self, i, j):
        return self.translations[i, j, :]

    def get_inliers(self, i, j):
        return self.inlier_matches[i, j]

    def compute_pairwise_registrations(self, q, i, fov):
        matched = np.ones([self._num, 1], dtype=np.int32) * TransformationFinder.UNMATCHED

        # while anything is still unmatched
        total_matched = 0
        while np.any(matched == TransformationFinder.UNMATCHED):

            # first unmatched image
            # match to self, ie new global ref
            id_unmatched = np.argmin(matched)
            matched[id_unmatched] = id_unmatched

            # if add new ref check again
            new_ref = True

            while new_ref:

                # make sure something is added
                new_ref = False

                # search through images we will move
                for src_mm in range(self._num):

                    # print progress
                    num_matched = np.sum(matched != TransformationFinder.UNMATCHED)
                    if num_matched > total_matched:
                        total_matched = num_matched
                        q.put((num_matched, self._num, i, fov))
                        # utils.printProgressBar(total_matched, self._num)

                    # if this is already matched skip
                    if matched[src_mm] != TransformationFinder.UNMATCHED:
                        continue

                    most_inliers = 0
                    best_dst_id = -1

                    # search through possible destination images
                    for dst_mm in self.closest_mm_images[src_mm]:

                        # if images are same, or the dstination hasnt been matched
                        if (dst_mm == src_mm) or (matched[dst_mm] == TransformationFinder.UNMATCHED):
                            continue

                        # if we havent calculated everything already
                        if not self.have_computed[src_mm, dst_mm]:
                            self.compute_translation(src_mm, dst_mm)

                        # if better than all previous
                        if self.inlier_matches[src_mm, dst_mm] >= most_inliers:
                            most_inliers = self.inlier_matches[src_mm, dst_mm]
                            best_dst_id = dst_mm

                            if most_inliers >= TransformationFinder.auto_accept:
                                break

                    if most_inliers > self.min_inliers:
                        matched[src_mm] = best_dst_id
                        new_ref = True
        self.matched = matched


class InputPipeline:
    """
        Triples images together, confocal, avg, and split. Returning
        a list of MultiModalImage objects.
    """

    def __init__(self, directory, excell, name_convention, eye):
        """
            directory: where all your images live
            excell: path to excell file
            name_convention: how modalities are distinguished
                             in filenames
            eye: which eye
            self.directory
            self.excell
            self.name_convention
            self.eye
            self.filenames_and_position:
                list of dictionaries with paths of all modalities
                and the nominal position extracted from the excell
                file

        """

        # build dict with
        # self.nominal_dictionary[movie_number] = nominal_position
        self.eye = eye
        self.directory = directory
        self.name_convention = name_convention
        self.position_map = self.build_position_map()
        self.nominal_dictionary = self.build_nominal_dictionary(excell)

        # save all three image filenames to a list
        # along with the actual nominal position
        image_names = self.get_all_tifs_in_dir()
        combined_modality = self.combine_images(image_names)
        self.triples_by_fov = self.get_nominal(combined_modality)

    def build_position_map(self):
        pos_map = {
            'c': (0.0, 0.0),
            'trc': (0.6, 0.6),
            'mre': (0.0, 0.6),
            'brc': (-0.6, 0.6),
            'mbe': (-0.6, 0.0),
            'blc': (-0.6, -0.6),
            'mle': (0.0, -0.6),
            'mrc': (0.0, 0.6),
            'tlc': (0.6, -0.6),
            'mte': (0.6, 0.0),
            'centre': (0., 0.),
            'center': (0., 0.),
            's': (1., 0.),
            'i': (-1., 0.),
            'n': (0., -1.) if self.eye == 'OD' else (0., 1.),
            't': (0., 1.) if self.eye == 'OD' else (0., -1.)
        }
        return pos_map

    def convert_xlsx_pos_to_coord(self, text_location):
        """transforms text to nominal location"""
        try:
            text_location = text_location.lower()
        except AttributeError:
            print('given location in excell file is not string: {}'.format(text_location))
        digits_in_text_location = [float(x) for x in re.findall(r"[-+]?\d*\.\d+|\d+", text_location)]

        # contains digits then its coordinate form
        # we strip the letters which are just a basis
        # and add and multiply according to digits
        if digits_in_text_location:
            # remove everything that is not a coordinate letter
            text_location = re.sub('[^nsti]', '', text_location)
            letters = text_location
            location = np.zeros([2])
            for k in range(len(letters)):
                location += digits_in_text_location[k] * np.array(self.position_map[letters[k]])
        # No digits: either a mistake or one of the existing names
        # in self.position_map
        else:
            try:
                location = np.array(self.position_map[text_location])
            except KeyError:
                print('Warning: movie had unrecognised position {}'.format(text_location))
                print('Assuming central')
                location = np.zeros([2])

        return location

    def build_nominal_dictionary(self, excell):
        movie_nums, movie_locs, fovs = self.read_xlsx(excell)
        nominal_dictionary = {movie_nums[i]: (movie_locs[i], fovs[i]) for i in range(len(movie_nums))}
        return nominal_dictionary

    def read_xlsx(self, excell):

        workbook = xlrd.open_workbook(excell)
        worksheet = workbook.sheet_by_index(0)

        movie_nums = worksheet.col_values(0)
        movie_locs = worksheet.col_values(1)
        fovs = worksheet.col_values(2)
        movie_nums = [int(x) for x in movie_nums]
        movie_locs = [self.convert_xlsx_pos_to_coord(x) for x in movie_locs]
        fovs = [float(x) for x in fovs]
        assert len(movie_nums) == len(movie_locs)
        assert len(movie_locs) == len(fovs)

        return movie_nums, movie_locs, fovs

    def get_all_tifs_in_dir(self, ):
        tif_fnames = [x for x in os.listdir(self.directory) if x[-4:] == '.tif']
        tif_paths = [os.path.join(self.directory, x) for x in tif_fnames]
        return tif_paths

    def channel_from_fname(self, fname):
        for key in self.name_convention:
            val = self.name_convention[key]
            if val in fname:
                return key
        raise ValueError('Found fname %s without valid channel name' %(fname))

    def _triple_first_image(self, image_names):
        triple = {}
        channels = set(self.name_convention.keys())
        curr_to_triple = image_names[0]
        channel_type = self.channel_from_fname(curr_to_triple)
        triple[channel_type] = curr_to_triple
        image_names.remove(curr_to_triple)
        remaining_channels = (channels - {channel_type})
        for other_channel in remaining_channels:
            other_channel_fname = curr_to_triple.replace(
                self.name_convention[channel_type],
                self.name_convention[other_channel], )
            triple[other_channel] = other_channel_fname
            image_names.remove(other_channel_fname)

        return image_names, triple

    def combine_images(self, image_names):
        """Triple flat image list so tripled with other channels, conf, split, avg"""

        list_length = len(image_names)
        assert list_length%3==0, 'Number of images not divisible by three'

        tripled_images = []
        while len(image_names) > 0:
            image_names, triple = self._triple_first_image(image_names)
            tripled_images.append(triple)

        return tripled_images

    def movie_num_from_triple(self, triple):
        """
            extract the movie_number from an image name.
            assumes that the movie number 0000 appears as
                ******self.name_convention['confocal']_0000*************
        """
        conf_name = self.name_convention['confocal']
        fname = triple['confocal']
        idx = fname.index(conf_name + '_') + len(conf_name + '_')
        num_str = fname[idx:idx + 4] if fname[idx:idx + 4] == '0000' else fname[idx:idx + 4].lstrip('0')
        movie_num = int(num_str)
        return movie_num

    def attach_location_to_triple(self, triple):
        movie_num = self.movie_num_from_triple(triple)
        try:
            triple['nominal'] = self.nominal_dictionary[movie_num][0]
            triple['fov'] = self.nominal_dictionary[movie_num][1]
        except KeyError:
            print('Warning: when trying to attach locations to triples')
            print('movie {} had no (position or FOV)'.format(movie_num))
            print('Assuming central and continuing')
            triple['nominal'] = np.zeros([2])
        return triple

    def get_nominal(self, triples):
        triples_by_fov = {}
        for triple in triples:
            with_pos = self.attach_location_to_triple(triple)
            if with_pos['fov'] in triples_by_fov.keys():
                triples_by_fov[with_pos['fov']].append(with_pos)
            else:
                triples_by_fov[with_pos['fov']] = [with_pos]

        return triples_by_fov

    def __getitem__(self, i):
        return self.triples_by_fov[i]

    def __len__(self,):
        return len(self.triples_by_fov)

    def as_multi_modal_objects(self, ):
        mm_dict = {}

        min_fov = min(list(self.triples_by_fov.keys()))
        for fov in self.triples_by_fov:
            if min_fov == fov:
                resize = None
            else:
                resize = fov / min_fov
            mm_dict[fov] = [
                MultiModalImage(
                    triple['confocal'],
                    triple['split'],
                    triple['avg'],
                    triple['nominal'],
                    fov,
                    resize)
                for triple in self.triples_by_fov[fov]
            ]
        mms = [ x for sublist in mm_dict.values() for x in sublist]
        mms_dict = {}
        mms_dict[min_fov] = mms
        return mms_dict

# todo: remove previous section

# main
def main(directory, nominal, eye, naming, photoshop_directory, q, e):

    print(directory)
    alg_start = time()
    # gets all our files matched with different modalities
    print('Getting all files ...')
    m = InputPipeline(directory, nominal, naming, eye)
    mmList = m.as_multi_modal_objects()

    # calculates all keypoints and descriptors
    # then constructs a global registration out
    # of pairwise registrations
    for i, fov in enumerate(mmList):
        s = time()
        print('Computing keypoints and descriptors for {} fov...'.format(fov))
        tf = TransformationFinder(mmList[fov])
        tf.compute_kps_desc()

        print('Building registrations for {} fov...'.format(fov))
        tf.compute_pairwise_registrations(q, i, fov)

        print('Finished {} fov!'.format(fov))
        print('took {}'.format(time() - s))

        # list of lists. The top layer is disjoint
        # montages, followed by the transformations
        # and file names needed
        mb = MontageBuilder(tf, evaluate=False)
        disjoint_montages = mb.construct_all_montages()

        print('Creating photoshop script ...')
        transformations = [x[0] for x in disjoint_montages]
        name = 'create_recent_montage_' + str(fov) + '_fov'
        write_photoshop_script(transformations, photoshop_directory, name=name)
    e.set()
    print('Total time taken {}'.format(time() - alg_start))
    # todo clean up temp


# set up queue
this_queue = queue.Queue()
this_event = Event()
t = Thread(target=main, args=(imgPath, posFFname, eyeOX, modScheme, outPath, this_queue, this_event))
t.start()

# Run automontager
#main(directory, nominal, eye, naming, photoshop_directory, q, e)
