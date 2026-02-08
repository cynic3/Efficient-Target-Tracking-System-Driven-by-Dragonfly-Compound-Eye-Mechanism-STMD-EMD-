function [img_files,img_data,img_groundtruth]=read_file_RIST(sequence_name,dataset)
%dataset="Rist";
%sequence_name = "GX010230-1";
%target_size=5;
if dataset=="Rist"
        datadir='C:/Users/Administrator/Desktop/STMD/image data/';
        path = strcat(datadir,sequence_name,'/');
        img_path = path;
        % D = dir(strcat(img_path, '*.jpg'));
        % seq_len = length(D(not([D.isdir])));
        img_dir=strcat(img_path, strcat('Real-Image',num2str(1, '%04i.jpg')));
        if exist(img_dir, 'file')
            
            gt_path = strcat(path, strcat(sequence_name,'ViTBAT.mat'));
            ViTBAT = load(gt_path);
            img_groundtruth=ViTBAT.data_gt.GtInterpolated(:,[3 4]);
            img_size=size(img_groundtruth);
            img_len=img_size(1);
            img_files = num2str((1:img_len)', strcat(img_path,'Real-Image%04i.jpg'));
            img=imread(img_files(1,:));
            [m,n,p]=size(img);
            img_data=zeros(m,n,p,img_len);
            for i = 1:img_len
                img=imread(img_files(i,:));
                img_data(:,:,:,i)=im2double(img);
            end
        else
            error('No image files found in the directory.');
        end
else
    error('No dataset files found in the directory.');
end
