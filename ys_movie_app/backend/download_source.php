<?php
/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 功能：Flutter源码包下载接口（带鉴权）
 * 说明：GitHub Actions构建时从此接口下载源码，防止源码暴露
 */

// 配置
$config = [
    'token' => 'jgapp-cloud-build-2024-secret-key',
    'source_path' => __DIR__ . '/../../flutter_app_source.zip',
];

// 获取请求Token（兼容多种服务器环境）
$authHeader = '';
if (!empty($_SERVER['HTTP_AUTHORIZATION'])) {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
} elseif (!empty($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
    $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
} elseif (function_exists('apache_request_headers')) {
    $headers = apache_request_headers();
    $authHeader = $headers['Authorization'] ?? '';
}

$requestToken = '';
if (preg_match('/Bearer\s+(.+)/i', $authHeader, $matches)) {
    $requestToken = $matches[1];
}

// 鉴权检查
if ($requestToken !== $config['token']) {
    http_response_code(401);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['code' => 0, 'msg' => 'Unauthorized: Invalid token']);
    exit;
}

// 检查源码包是否存在
if (!file_exists($config['source_path'])) {
    http_response_code(404);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['code' => 0, 'msg' => 'Source package not found at: ' . $config['source_path']]);
    exit;
}

// 输出源码包
header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="flutter_app_source.zip"');
header('Content-Length: ' . filesize($config['source_path']));
header('Cache-Control: no-cache, must-revalidate');

readfile($config['source_path']);
exit;
