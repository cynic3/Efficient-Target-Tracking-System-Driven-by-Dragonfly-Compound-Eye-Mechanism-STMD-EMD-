clear all
close all
% img import
dataset="Rist";
% sequence_name = "GX010327-1";
sequence_name = "GX010230-1";
[img_files, img_data, img_groundtruth]=read_file_RIST(sequence_name,dataset);
disp("数据导入结束");
% test config
% 1: ON  2: OFF
img_show_preprocess=0;
img_show_STMDarray=0;
img_show_EMDarray=0;
img_save=1;
num=5;

% img params
[img_hit, img_wid, img_col, img_len]=size(img_data);
sampling_time=1/50; % 50 frame/s
% start frame
start_frame=1;
% end_frame=start_frame+round(img_len/20);
%end_frame=img_len;
end_frame=256;
% Gaussian Filter
Fsize1=7; sigma1=3.5; K1=3;
filter_gaussian=fspecial('gaussian',Fsize1,sigma1);

% Centre-surround antagonism
Fsize2=3; sigma2_1=1; sigma2_2=1.5*sigma2_1;
% filter_antagonsim=fspecial('gaussian',Fsize2,sigma2_1)-0.1*fspecial('gaussian',Fsize2,sigma2_2);
filter_antagonsim=[-1/9 -1/9 -1/9
    -1/9  8/9 -1/9
    -1/9 -1/9 -1/9];

% Gamma Filter % if tau need to be set as self adaptive? -> NO!
alpha1=0.8;alpha2=0.7;
% Centre-Surround Antagonism
CSA_KS=[-1 -1 -1 -1 -1
    -1 -1 -1 -1 -1
    -1 -1  2 -1 -1
    -1 -1 -1 -1 -1
    -1 -1 -1 -1 -1];
CSA_KM=[-1 -1 -1 -1 -1
    -1  0  0  0 -1
    -1  0  2  0 -1
    -1  0  0  0 -1
    -1 -1 -1 -1 -1];
CSA_KL=[-1 -1 -1 -1 -1
    -1  2  2  2 -1
    -1  2  2  2 -1
    -1  2  2  2 -1
    -1 -1 -1 -1 -1];
% Low_Pass Filter in STMD
STMD_LP_low=49;
% Array
step = 0.01;                                       % temporal resolution of the EMD array in [s].
% low-pass filter.
tauL = 0.050;                                      % the LP filter's time constant in [s].
dL = tauL/step;
EMD_LP_low(1, 1) = 1/(dL+1);
EMD_LP_low(1, 2)= 1-EMD_LP_low(1, 1);

% EMD output save
mkdir(strcat('results/',sequence_name,'_',num2str(start_frame),'-',num2str(end_frame)));


% Initiation -> to calculate faster
img_hit_new=img_hit/K1; img_wid_new=img_wid/K1;
img_green=zeros(img_hit,img_wid,img_len);
img_blur=zeros(img_hit,img_wid,img_len);
img_samp=zeros(img_hit_new, img_wid_new,img_len);
img_inhi=zeros(img_hit_new, img_wid_new,img_len);
img_band=zeros(img_hit_new, img_wid_new,img_len);
HWR1_On=zeros(img_hit_new, img_wid_new,img_len);
HWR1_Off=zeros(img_hit_new, img_wid_new,img_len);
tau_FA_On=zeros(img_hit_new, img_wid_new);
tau_FA_Off=zeros(img_hit_new, img_wid_new);
alpha_FA_On=zeros(img_hit_new, img_wid_new);
alpha_FA_Off=zeros(img_hit_new, img_wid_new);
Fa_Filter_On=zeros(img_hit_new, img_wid_new,img_len);
Fa_Filter_Off=zeros(img_hit_new, img_wid_new,img_len);
Fa_output_On=zeros(img_hit_new, img_wid_new,img_len);
Fa_output_Off=zeros(img_hit_new, img_wid_new,img_len);
CSA_On=zeros(img_hit_new, img_wid_new,img_len);
CSA_Off=zeros(img_hit_new, img_wid_new,img_len);
HWR2_On=zeros(img_hit_new, img_wid_new,img_len);
HWR2_Off=zeros(img_hit_new, img_wid_new,img_len);
LP_STMD_On=zeros(img_hit_new, img_wid_new,img_len);
LP_STMD_Off=zeros(img_hit_new, img_wid_new,img_len);
STMD_Output=zeros(img_hit_new, img_wid_new,img_len);
Fd=zeros(img_hit_new, img_wid_new,img_len);
H=zeros(img_hit_new-1, img_wid_new-1,img_len);
V=zeros(img_hit_new-1, img_wid_new-1,img_len);
% EMD_Output=zeros(img_hit_new-1, img_wid_new-1,img_len);

if img_save==1
    f1=figure('Name','EMD_OUTPUT');
    set(gcf, 'Units','normalized','Position', [0.05 0.1 0.9 0.8],'Resize','off','visible','on');
end


% start processing
for t = start_frame:end_frame
    disp(t);
    % select green channel
    img_green(:,:,t)=img_data(:,:,2,t);
    % Spatial Gaussian Filter
    img_blur(:,:,t)=imfilter(img_green(:,:,t),filter_gaussian);
    % Down Sampling
    img_samp(:,:,t)=img_blur(1:K1:end, 1:K1:end,t);
    % Down Sampling gt
    img_groundtruth_samp(t,:)=img_groundtruth(t,:)./K1; % to be confirmed -> YES!
    % Centre-surround antagonism
    img_inhi(:,:,t)=imfilter(img_samp(:,:,t),filter_antagonsim);
    % disp("下采样结束");
    if t==start_frame
        img_band(:,:,t)=img_inhi(:,:,t);
        On(:,:,t)  = Rect( 1, img_band(:,:,t), 0);
        Off(:,:,t) = Rect(-1, img_band(:,:,t), 0);
    else
        % Bandpass Filter
        img_band(:,:,t)=alpha1*(img_inhi(:,:,t)-img_inhi(:,:,t-1))+alpha2*img_band(:,:,t-1);
        % img_band(:,:,t)=img_inhi(:,:,t);
        % ESTMD stage
        % Half_Wave Recitifier 1
        HWR1_On(:,:,t)  = Rect( 1, img_band(:,:,t), 0);
        HWR1_Off(:,:,t) = Rect(-1, img_band(:,:,t), 0);
        % Fast Adaptation
        % Gradient Check
        tau_FA_On(:,:)=GradientCheck(HWR1_On(:,:,t),HWR1_On(:,:,t-1));
        tau_FA_Off(:,:)=GradientCheck(HWR1_Off(:,:,t),HWR1_Off(:,:,t-1));
        % Fast Low_Pass Filter
        alpha_FA_On(:,:)=exp(-sampling_time./tau_FA_On(:,:));
        alpha_FA_Off(:,:)=exp(-sampling_time./tau_FA_Off(:,:));
        Fa_Filter_On(:,:,t)=(1-alpha_FA_On).*HWR1_On(:,:,t)+alpha_FA_On.*Fa_Filter_On(:,:,t-1);
        Fa_Filter_Off(:,:,t)=(1-alpha_FA_On).*HWR1_Off(:,:,t)+alpha_FA_Off.*Fa_Filter_Off(:,:,t-1);
        Fa_output_On(:,:,t)=-Fa_Filter_On(:,:,t)+HWR1_On(:,:,t);
        Fa_output_Off(:,:,t)=-Fa_Filter_Off(:,:,t)+HWR1_Off(:,:,t);
        % Centeral-Surround Antagonism
        CSA_On(:,:,t)=imfilter(Fa_output_On(:,:,t),CSA_KL);
        CSA_Off(:,:,t)=imfilter(Fa_output_Off(:,:,t),CSA_KL);
        % Half_Wave Recitifier 2
        HWR2_On(:,:,t)  = Rect(1,CSA_On(:,:,t), 0);
        HWR2_Off(:,:,t) = Rect(1,CSA_Off(:,:,t), 0);
        LP_STMD_On(:,:,t)  = 1/51*(HWR2_On(:,:,t) + (HWR2_On(:,:,t-1)+STMD_LP_low.*LP_STMD_On(:,:,t-1)));
        LP_STMD_Off(:,:,t) = 1/51*(HWR2_Off(:,:,t) + (HWR2_Off(:,:,t-1)+STMD_LP_low.*LP_STMD_Off(:,:,t-1)));

        STMD_Output(:,:,t)=LP_STMD_On(:,:,t).*HWR2_Off(:,:,t)+LP_STMD_Off(:,:,t).*HWR2_On(:,:,t);

        %------------------
        % EMD stage -> velocity estimator
        % Fd(:,:,t)  = EMD_LP_low(1, 1)*STMD_Output(:,:,t-1) + EMD_LP_low(1, 2)*Fd(:,:,t-1);
        % H(1:(img_hit_new-1), 1:(img_wid_new-1),t) = Fd(1:(img_hit_new-1), 1:(img_wid_new-1),t).*STMD_Output(1:(img_hit_new-1), 2:img_wid_new,t)-STMD_Output(1:(img_hit_new-1), 1:(img_wid_new-1),t).*Fd(1:(img_hit_new-1), 2:img_wid_new,t);
        % V(1:(img_hit_new-1), 1:(img_wid_new-1),t) = Fd(1:(img_hit_new-1), 1:(img_wid_new-1),t).*STMD_Output(2:img_hit_new, 1:(img_wid_new-1),t)-STMD_Output(1:(img_hit_new-1), 1:(img_wid_new-1),t).*Fd(2:img_hit_new, 1:(img_wid_new-1),t);
        % EMD_Output(:,:,t)=H(1:(img_hit_new-1), 1:(img_wid_new-1),t)+V(1:(img_hit_new-1), 1:(img_wid_new-1),t);
        EMD_Output(:,:,t)=STMD_Output(:,:,t);

        
        if t==start_frame+1
            loc_estm=img_groundtruth_samp(1,:);
            loc_recd(t,:)=[loc_estm(1) loc_estm(2)];
        % attention_filter=gaussC(img_hit_new,img_wid_new,3,[loc_estm(2) loc_estm(1)]);
        
        else
            
           % EMD_Output_new(:,:,t)=conv2(EMD_Output(:,:,t),attention_filter,'same');
            result=EMD_Output(:,:,t);result=result.*1e8;
        [loc_estm(1), loc_estm(2)]=find(result==max(result,[],"all"));
        loc_recd(t,:)=[loc_estm(1), loc_estm(2)];
         
         % attention_filter=gaussC(img_hit_new,img_wid_new,3,[loc_estm(2) loc_estm(1)]);
            %------------------
            % save pics
            if img_save==1


                loc_gt=img_groundtruth_samp(t,:);
                result=EMD_Output(:,:,t);
                % result=result.*1e8;
                % result=result-mode(result,"all");
                % result=normalize(result,'center','median');
                

                % result=insertShape(result, "circle",[loc_gt(1) loc_gt(2) 5],'LineWidth',1,'SmoothEdges',false);
                result_name=strcat('results/',sequence_name,'_',num2str(start_frame),'-',num2str(end_frame),'/STMD_Output',num2str(t, '%04i.tiff'));
                imagesc(result);hold on;colormap("gray");axis off;
                r = 5;%半径
                a = loc_gt(1);%横坐标
                b = loc_gt(2);%纵坐标
                theta = 0:pi/20:2*pi; %角度[0,2*pi]
                x = a+r*cos(theta);
                y = b+r*sin(theta);
                plot(x,y,'-','Color','yellow');
                plot(loc_estm(2),loc_estm(1), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); hold off;
                title(result_name,'Interpreter','none');
                set(gca,'Position',[0.05 0.05 0.9 0.9],'DataAspectRatio',[1,1,1]);
                % 保存为高清 PNG（默认分辨率 300 DPI）
                exportgraphics(f1, result_name, 'Resolution', 300);
            end
        end
    end
end

% -------------
% measurement
%calculate distances to ground truth over all frames
LE_threshold=5;
loc_gt=img_groundtruth_samp(1:end_frame,:)';
distances = sqrt((loc_recd(start_frame:end_frame,2)'-loc_gt(1,start_frame:end_frame)).^2 + (loc_recd(start_frame:end_frame,1)'-loc_gt(2,start_frame:end_frame)).^2);
distances(isnan(distances)) = [];
figure('Name','Location Error');
frame_false=find(distances>LE_threshold);
frame_correct=find(distances<=LE_threshold);
plot(distances,'*r','MarkerIndices',frame_false);hold on;
plot(distances,'*g','MarkerIndices',frame_correct);
xlabel('Frame Number'); ylabel("Location Error (Pixel)");
hold off;
loc_correct=distances(distances<=LE_threshold);
correct_rate=length(loc_correct)/length(distances);
title(append("Location Error (Precision@",num2str(LE_threshold),"=",num2str(correct_rate),")"));
legend(append('Threshold >',num2str(LE_threshold)),append('Threshold <= ',num2str(LE_threshold)),'Location','NE');
%--------------
% display
loc=img_groundtruth(num,:);
loc_samp=img_groundtruth_samp(num,:);
if img_show_preprocess==1
    figure("Name","Preprocess");
    set(gcf, 'Units','normalized','Position', [0.05 0.1 0.9 0.8],'Resize','off');
    %
    subplot(2,3,1);
    imshow(img_data(:,:,:,num)); hold on;
    plot(loc(1),loc(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); hold off;
    set(gca,'Position',[0.0475 0.51 0.27 0.48]);
    title(append("Original Input (N=",num2str(num),")"));
    %
    subplot(2,3,2);
    imshow(img_green(:,:,num)); hold on;
    plot(loc(1),loc(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); hold off;
    set(gca,'Position',[0.365 0.51 0.27 0.48]);
    title("Green Channel Selection");
    %
    subplot(2,3,3);
    imshow(img_blur(:,:,num)); hold on;
    plot(loc(1),loc(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); hold off;
    set(gca,'Position',[0.6825 0.51 0.27 0.48]);
    title("Gaussian Blur");
    %
    subplot(2,3,4);
    imshow(img_samp(:,:,num)); hold on;
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); hold off;
    set(gca,'Position',[0.0475 0.01 0.27 0.48]);
    title("Down Sampling (Retina Output)");
    %
    subplot(2,3,5)
    imagesc(img_inhi(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'Position',[0.365 0.01 0.27 0.48],'DataAspectRatio',[1,1,1]);
    title("Centre-Surround Antagonism");
    %
    subplot(2,3,6)
    imagesc(img_band(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'position',[0.6825 0.01 0.27 0.48],'DataAspectRatio',[1,1,1]);
    title("Neural Adaptation (Lamina Output)");
end
if img_show_STMDarray==1
    figure("Name","STMD Array");
    set(gcf, 'Units','normalized','Position', [0.05 0.1 0.9 0.8],'Resize','off');
    %
    subplot(2,4,1);
    imagesc(HWR1_On(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('HWR1 ON');
    %
    subplot(2,4,5);
    imagesc(HWR1_Off(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('HWR1 OFF');
    %
    subplot(2,4,2);
    imagesc(Fa_output_On(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('Fast Adaptation ON');
    %
    subplot(2,4,6);
    imagesc(Fa_output_Off(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('Fast Adaptation OFF');
    %
    subplot(2,4,3);
    imagesc(HWR2_On(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('HWR2 ON');
    %
    subplot(2,4,7);
    imagesc(HWR2_Off(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('HWR2 OFF');
    %
    subplot(2,4,[4 8]);
    imagesc(STMD_Output(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title('STMD output');
end

if img_show_EMDarray==1
    figure("Name","EMD Array");
    set(gcf, 'Units','normalized','Position', [0.05 0.1 0.9 0.8],'Resize','off');

    loc_samp=img_groundtruth_samp(num,:);
    loc_samp(1)=loc_samp(1)*img_hit_new/(img_hit_new-1);
    loc_samp(2)=loc_samp(2)*img_wid_new/(img_wid_new-1);
    %
    subplot(2,3,1)
    imagesc(H(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title("Horizontal");
    %
    subplot(2,3,4)
    imagesc(V(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title("Vertical")
    %
    subplot(2,3,[2 3 5 6])
    imagesc(EMD_Output(:,:,num));hold on; colormap("gray");
    plot(loc_samp(1),loc_samp(2), 'r*', 'MarkerSize', 5, 'LineWidth', 0.5); axis off; hold off;
    set(gca,'DataAspectRatio',[1,1,1]);
    title("EMD output");
end