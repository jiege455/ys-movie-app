<?php
/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 功能：上传图标和启动图接口
 * 说明：接收用户上传的图片文件，保存到服务器并返回URL
 */

header('Content-Type: application/json; charset=utf-8');

// 上传目录
$uploadDir = __DIR__ . '/../../uploads/app_icons/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// 获取上传类型
$type = $_POST['type'] ?? 'icon'; // icon 或 splash

// 检查文件
if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(['code' => 0, 'msg' => '上传失败：' . ($_FILES['file']['error'] ?? '未知错误')]);
    exit;
}

$file = $_FILES['file'];

// 验证文件类型
$allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
if (!in_array($file['type'], $allowedTypes)) {
    echo json_encode(['code' => 0, 'msg' => '文件类型错误，只允许上传 PNG、JPG、WEBP 图片']);
    exit;
}

// 验证文件大小（最大5MB）
$maxSize = 5 * 1024 * 1024;
if ($file['size'] > $maxSize) {
    echo json_encode(['code' => 0, 'msg' => '文件过大，最大允许5MB']);
    exit;
}

// 生成文件名
$ext = pathinfo($file['name'], PATHINFO_EXTENSION);
$filename = $type . '_' . date('YmdHis') . '_' . rand(1000, 9999) . '.' . $ext;
$filepath = $uploadDir . $filename;

// 移动文件
if (move_uploaded_file($file['tmp_name'], $filepath)) {
    // 获取当前域名
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $baseUrl = $scheme . '://' . $host;
    
    $fileUrl = $baseUrl . '/uploads/app_icons/' . $filename;
    
    echo json_encode([
        'code' => 1,
        'msg' => '上传成功',
        'data' => [
            'url' => $fileUrl,
            'filename' => $filename,
            'size' => $file['size']
        ]
    ]);
} else {
    echo json_encode(['code' => 0, 'msg' => '保存文件失败']);
}
