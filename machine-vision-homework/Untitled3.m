%% 快递包裹面单区域定位与截取系统 (MATLAB 2016版)
clear; clc; close all;

%% 参数设置
input_image_path = 'kuaidi.jpg';
output_labeled_path = 'kuaidi.jpg';
output_cropped_path = 'kuaidi.jpg';

gaussian_sigma = 1.5;
gaussian_size = 5;
canny_low_thresh = 0.1;
canny_high_thresh = 0.3;
morph_dilate_size = 5;
morph_close_size = 15;
min_area_ratio = 0.02;
max_area_ratio = 0.8;
min_aspect_ratio = 0.3;
max_aspect_ratio = 3.0;
min_rectangularity = 0.6;

%% 第一步：读取图像
fprintf('【步骤1】读取输入图像...\n');
if ~exist(input_image_path, 'file')
    error('输入图像不存在：%s', input_image_path);
end

original_img = imread(input_image_path);
[img_height, img_width, ~] = size(original_img);
fprintf('  图像尺寸：%d × %d\n', img_width, img_height);

figure('Name', '面单定位处理流程', 'Position', [100, 100, 1200, 800]);
subplot(2, 3, 1);
imshow(original_img);
title('原始图像');

%% 第二步：灰度化
fprintf('【步骤2】图像灰度化...\n');
if size(original_img, 3) == 3
    gray_img = rgb2gray(original_img);
else
    gray_img = original_img;
end

subplot(2, 3, 2);
imshow(gray_img);
title('灰度图像');

%% 第三步：滤波降噪
fprintf('【步骤3】高斯滤波降噪...\n');
h_gauss = fspecial('gaussian', gaussian_size, gaussian_sigma);
filtered_img = imfilter(gray_img, h_gauss, 'same', 'replicate');

subplot(2, 3, 3);
imshow(filtered_img);
title('滤波降噪后图像');

%% 第四步：边缘检测
fprintf('【步骤4】Canny边缘检测...\n');
edge_img = edge(filtered_img, 'Canny', [canny_low_thresh, canny_high_thresh]);

subplot(2, 3, 4);
imshow(edge_img);
title('边缘检测结果');

%% 第五步：形态学处理
fprintf('【步骤5】形态学处理...\n');
se_dilate = strel('square', morph_dilate_size);
se_close = strel('square', morph_close_size);

dilated_img = imdilate(edge_img, se_dilate);
closed_img = imclose(dilated_img, se_close);
opened_img = imopen(closed_img, strel('square', 3));
morph_img = imdilate(opened_img, strel('square', 5));

subplot(2, 3, 5);
imshow(morph_img);
title('形态学处理结果');

%% 第六步：轮廓检测与筛选
fprintf('【步骤6】轮廓检测与筛选...\n');

[B, L] = bwboundaries(morph_img, 'noholes');
stats = regionprops(L, 'Area', 'BoundingBox', 'Perimeter', 'Extent');

fprintf('  检测到 %d 个候选区域\n', length(stats));

total_area = img_height * img_width;
candidate_regions = [];

for i = 1:length(stats)
    area = stats(i).Area;
    bbox = stats(i).BoundingBox;
    
    area_ratio = area / total_area;
    
    aspect_ratio = bbox(3) / bbox(4);
    if aspect_ratio < 1
        aspect_ratio = 1 / aspect_ratio;
    end
    
    bbox_area = bbox(3) * bbox(4);
    rectangularity = area / bbox_area;
    
    if (area_ratio >= min_area_ratio) && ...
       (area_ratio <= max_area_ratio) && ...
       (aspect_ratio >= min_aspect_ratio) && ...
       (aspect_ratio <= max_aspect_ratio) && ...
       (rectangularity >= min_rectangularity)
        
        candidate_regions = [candidate_regions; ...
            i, area, bbox(1), bbox(2), bbox(3), bbox(4), rectangularity, stats(i).Extent];
    end
end

fprintf('  筛选后剩余 %d 个候选面单区域\n', size(candidate_regions, 1));

%% 第七步：选择最优面单区域
fprintf('【步骤7】选择最优面单区域...\n');

if isempty(candidate_regions)
    warning('未检测到符合条件的面单区域，将使用最大轮廓作为结果');
    max_area = 0;
    max_idx = 1;
    for i = 1:length(stats)
        if stats(i).Area > max_area
            max_area = stats(i).Area;
            max_idx = i;
        end
    end
    best_bbox = stats(max_idx).BoundingBox;
else
    scores = zeros(size(candidate_regions, 1), 1);
    for i = 1:size(candidate_regions, 1)
        area = candidate_regions(i, 2);
        rect = candidate_regions(i, 7);
        
        area_score = min(area / (total_area * 0.3), 1);
        rect_score = rect;
        
        scores(i) = 0.4 * area_score + 0.6 * rect_score;
    end
    
    [~, best_idx] = max(scores);
    best_bbox = candidate_regions(best_idx, 3:6);
end

fprintf('  面单位置：x=%.1f, y=%.1f, 宽=%.1f, 高=%.1f\n', ...
    best_bbox(1), best_bbox(2), best_bbox(3), best_bbox(4));

%% 第八步：标注与截取
fprintf('【步骤8】标注面单并截取保存...\n');

labeled_img = original_img;
bbox_x = round(best_bbox(1));
bbox_y = round(best_bbox(2));
bbox_w = round(best_bbox(3));
bbox_h = round(best_bbox(4));

bbox_x = max(1, bbox_x);
bbox_y = max(1, bbox_y);
bbox_w = min(bbox_w, img_width - bbox_x + 1);
bbox_h = min(bbox_h, img_height - bbox_y + 1);

line_width = 3;
for i = 1:line_width
    x1 = max(1, bbox_x - i + 1);
    x2 = min(img_width, bbox_x + bbox_w - 1 + i - 1);
    y1 = max(1, bbox_y - i + 1);
    y2 = min(img_height, bbox_y + bbox_h - 1 + i - 1);
    
    labeled_img(y1, x1:x2, 1) = 255;
    labeled_img(y1, x1:x2, 2) = 0;
    labeled_img(y1, x1:x2, 3) = 0;
    
    labeled_img(y2, x1:x2, 1) = 255;
    labeled_img(y2, x1:x2, 2) = 0;
    labeled_img(y2, x1:x2, 3) = 0;
    
    labeled_img(y1:y2, x1, 1) = 255;
    labeled_img(y1:y2, x1, 2) = 0;
    labeled_img(y1:y2, x1, 3) = 0;
    
    labeled_img(y1:y2, x2, 1) = 255;
    labeled_img(y1:y2, x2, 2) = 0;
    labeled_img(y1:y2, x2, 3) = 0;
end

cropped_img = original_img(bbox_y:bbox_y+bbox_h-1, bbox_x:bbox_x+bbox_w-1, :);

subplot(2, 3, 6);
imshow(labeled_img);
title('面单定位结果');

figure('Name', '截取的面单图像', 'Position', [200, 200, 600, 400]);
imshow(cropped_img);
title('截取的面单区域');

%% 第九步：保存结果
fprintf('【步骤9】保存结果图像...\n');

imwrite(labeled_img, output_labeled_path);
imwrite(cropped_img, output_cropped_path);

fprintf('  标注图像已保存：%s\n', output_labeled_path);
fprintf('  截取面单已保存：%s\n', output_cropped_path);

%% 完成
fprintf('\n========================================\n');
fprintf('  面单定位与截取完成！\n');
fprintf('  面单位置：(%.1f, %.1f) - (%.1f, %.1f)\n', ...
    bbox_x, bbox_y, bbox_x+bbox_w, bbox_y+bbox_h);
fprintf('  面单尺寸：%d × %d 像素\n', bbox_w, bbox_h);
fprintf('========================================\n');