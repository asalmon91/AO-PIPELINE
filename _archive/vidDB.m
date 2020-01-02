classdef vidDB
    %vidDB is a collection of video sets
    
    properties
        vid_sets {vidset} = [];
    end
    
    methods
        function obj = vidDB(vid_sets)
            %vidDB Construct an instance of this class
            if nargin == 1
                obj.vid_sets = vid_sets;
            end
        end
        
%         function obj = addVidSets(obj, vid_sets)
%             new_vid_set_array = repmat(vidset, ...
%                 numel(obj.vid_sets)+numel(vid_sets), 1);
%             for ii=1:numel(obj.vid_sets)
%                 new_vid_set_array(ii) = obj.vid_sets(ii);
%             end
%             k=0;
%             for ii=numel(obj.vid_sets)+1:numel(obj.vid_sets)+numel(vid_sets)
%                 k=k+1;
%                 new_vid_set_array(ii) = vid_sets(k);
%             end
%             obj.vid_sets = new_vid_set_array;
        end
        
        function fnames = getAllFnames(obj)
            %getAllFnames returns of all filenames in the database
            
            n_vids = 0;
            for ii=1:numel(obj.vid_sets)
                n_vids = n_vids + numel(obj.vid_sets(ii).vids);
            end
            fnames = cell(n_vids, 1);
            
            k=1;
            for ii=1:numel(obj.vid_sets)
                these_fnames = getAllFnames(obj.vid_sets(ii));
                fnames{k:numel(these_fnames)} = these_fnames;
                k=k+numel(these_fnames);
            end
        end
    end
end

