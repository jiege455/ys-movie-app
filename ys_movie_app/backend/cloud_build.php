<?php
/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 功能：GitHub云端打包中转接口
 * 说明：用户在MacCMS后台填写配置，点击打包后，此接口创建GitHub仓库并触发Actions构建
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');

// 加载 MacCMS 核心
$macIncludePaths = [
    'include.php',
    '../include.php',
    '../../include.php',
    './include.php',
    dirname(__DIR__) . '/include.php',
    dirname(dirname(__DIR__)) . '/include.php',
];
$macIncludeFound = false;
foreach ($macIncludePaths as $macPath) {
    if (file_exists($macPath)) {
        require($macPath);
        $macIncludeFound = true;
        break;
    }
}
if (!$macIncludeFound) {
    echo json_encode(['code' => 0, 'msg' => '错误：找不到 include.php']);
    exit;
}

// 配置项
$ac = $_REQUEST['ac'] ?? '';

// 自动获取当前网站域名和协议
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'localhost';
$baseUrl = $scheme . '://' . $host;

// GitHub配置（从MacCMS配置读取或硬编码）
// 开发者：杰哥网络科技 (qq: 2711793818)
$githubConfig = [
    'token' => 'YOUR_GITHUB_PERSONAL_ACCESS_TOKEN',  // GitHub Personal Access Token（请替换为你的真实Token）
    'template_owner' => 'jiege455',  // 模板仓库所有者
    'template_repo' => 'flutter-build-template', // 模板仓库名（公开，只存脚本）
    'source_url' => $baseUrl . '/ys_movie_app/backend/download_source.php', // 源码包下载地址（自动获取当前域名）
    'source_token' => 'jgapp-cloud-build-2024-secret-key', // 源码下载鉴权Token（需与download_source.php一致）
];

// 辅助函数
function githubApi($url, $token, $method = 'GET', $data = null) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: token ' . $token,
        'Accept: application/vnd.github.v3+json',
        'User-Agent: CloudBuild/1.0',
        'Content-Type: application/json',
    ]);
    
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    } elseif ($method === 'PUT' || $method === 'PATCH') {
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    } elseif ($method === 'DELETE') {
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'code' => $httpCode,
        'data' => json_decode($response, true)
    ];
}

// [接口1] 创建打包任务
if ($ac == 'createBuild') {
    // 从CMS配置自动获取APP信息（jgapp插件配置）
    $cmsConfig = \think\Db::name('config')->where('group', 'getapp')->column('value', 'name');
    
    // 根据域名自动生成唯一且固定的包名，保证同一网站每次打包包名一致
    $hostParts = explode('.', $host);
    $hostParts = array_reverse($hostParts); // 反转：my→ddgg888→ys
    $domainPrefix = isset($hostParts[1]) ? $hostParts[1] : 'app';
    $domainMain = isset($hostParts[2]) ? $hostParts[2] : 'com';
    $autoPackageName = 'com.' . $domainMain . '.' . $domainPrefix . '.app';
    
    // 自动获取配置，如果CMS没有配置则使用域名自动生成的值
    $appName = !empty($cmsConfig['app_name']) ? $cmsConfig['app_name'] : '狐狸影视';
    $packageName = !empty($cmsConfig['package_name']) ? $cmsConfig['package_name'] : $autoPackageName;
    
    // 版本号：用户手动输入（必须填），默认 1.0.0
    $appVersion = $_REQUEST['app_version'] ?? '1.0.0';
    if (empty($appVersion)) {
        $appVersion = '1.0.0';
    }
    
    // 用户只需要上传logo图标
    $iconUrl = $_REQUEST['icon_url'] ?? '';
    $splashUrl = $_REQUEST['splash_url'] ?? ''; // 启动图可选
    
    $githubUsername = $_REQUEST['github_username'] ?? '';
    $githubToken = $_REQUEST['github_token'] ?? '';
    $buildPlatform = $_REQUEST['build_platform'] ?? 'android'; // android, ios, all
    
    // 自动获取当前网站域名作为API地址（指向APP的专用接口）
    $apiBaseUrl = $baseUrl . '/ys_movie_app/backend/app_api.php';
    
    // 验证平台参数
    if (!in_array($buildPlatform, ['android', 'ios', 'all'])) {
        $buildPlatform = 'android';
    }
    
    // 使用用户提供的GitHub Token或默认Token
    $token = !empty($githubToken) ? $githubToken : $githubConfig['token'];
    $username = !empty($githubUsername) ? $githubUsername : $githubConfig['template_owner'];
    
    // 生成唯一仓库名
    $repoName = 'app-build-' . time() . '-' . rand(1000, 9999);
    
    // 1. 从模板仓库创建新仓库
    $createUrl = 'https://api.github.com/repos/' . $githubConfig['template_owner'] . '/' . $githubConfig['template_repo'] . '/generate';
    $createResult = githubApi($createUrl, $token, 'POST', [
        'owner' => $username,
        'name' => $repoName,
        'description' => 'Auto build for ' . $appName,
        'private' => false,  // 公开仓库Actions免费
    ]);
    
    if ($createResult['code'] !== 201) {
        echo json_encode(['code' => 0, 'msg' => '创建仓库失败：' . ($createResult['data']['message'] ?? '未知错误')]);
        exit;
    }
    
    $repoFullName = $username . '/' . $repoName;
    
    // 2. 更新构建配置（创建/更新build_config.json）
    $configContent = base64_encode(json_encode([
        'app_name' => $appName,
        'package_name' => $packageName,
        'app_version' => $appVersion,
        'api_base_url' => $apiBaseUrl,
        'icon_url' => $iconUrl,
        'splash_url' => $splashUrl,
        'source_url' => $githubConfig['source_url'],
        'source_token' => $githubConfig['source_token'],
        'build_platform' => $buildPlatform, // 添加平台选择参数
    ]));
    
    $updateUrl = 'https://api.github.com/repos/' . $repoFullName . '/contents/build_config.json';
    $updateResult = githubApi($updateUrl, $token, 'PUT', [
        'message' => 'Update build config',
        'content' => $configContent,
    ]);
    
    if ($updateResult['code'] !== 201) {
        echo json_encode(['code' => 0, 'msg' => '更新配置失败：' . ($updateResult['data']['message'] ?? '未知错误')]);
        exit;
    }
    
    // 3. 触发GitHub Actions工作流（注意：文件名是 cloud_build.yml）
    $dispatchUrl = 'https://api.github.com/repos/' . $repoFullName . '/actions/workflows/cloud_build.yml/dispatches';
    $dispatchResult = githubApi($dispatchUrl, $token, 'POST', [
        'ref' => 'main',
    ]);
    
    if ($dispatchResult['code'] !== 204) {
        echo json_encode(['code' => 0, 'msg' => '触发构建失败：' . ($dispatchResult['data']['message'] ?? '未知错误')]);
        exit;
    }
    
    // 4. 保存构建记录到数据库
    $buildId = 'BUILD' . date('YmdHis') . rand(1000, 9999);
    \think\Db::name('cloud_build')->insert([
        'build_id' => $buildId,
        'repo_name' => $repoFullName,
        'app_name' => $appName,
        'package_name' => $packageName,
        'app_version' => $appVersion,
        'api_base_url' => $apiBaseUrl,
        'icon_url' => $iconUrl,
        'splash_url' => $splashUrl,
        'build_platform' => $buildPlatform,
        'status' => 'building',
        'github_username' => $username,
        'create_time' => time(),
    ]);
    
    // 返回时带上平台信息
    $buildInfo = \think\Db::name('cloud_build')->where('build_id', $buildId)->find();
    
    echo json_encode([
        'code' => 1,
        'msg' => '构建任务已创建',
        'data' => [
            'build_id' => $buildId,
            'repo_url' => 'https://github.com/' . $repoFullName,
            'status' => 'building',
            'build_platform' => $buildInfo['build_platform'] ?? 'android',
        ]
    ]);
    exit;
}

// [接口2] 查询构建状态
if ($ac == 'checkBuild') {
    $buildId = $_REQUEST['build_id'] ?? '';
    
    if (empty($buildId)) {
        echo json_encode(['code' => 0, 'msg' => '参数错误']);
        exit;
    }
    
    $buildInfo = \think\Db::name('cloud_build')->where('build_id', $buildId)->find();
    
    if (!$buildInfo) {
        echo json_encode(['code' => 0, 'msg' => '构建记录不存在']);
        exit;
    }
    
    // 如果正在构建，查询GitHub Actions状态
    if ($buildInfo['status'] === 'building') {
        $token = $githubConfig['token'];
        $runsUrl = 'https://api.github.com/repos/' . $buildInfo['repo_name'] . '/actions/runs?per_page=1';
        $runsResult = githubApi($runsUrl, $token);
        
        if ($runsResult['code'] === 200 && !empty($runsResult['data']['workflow_runs'])) {
            $run = $runsResult['data']['workflow_runs'][0];
            $runStatus = $run['status'];
            $runConclusion = $run['conclusion'];
            
            if ($runStatus === 'completed') {
                if ($runConclusion === 'success') {
                    // 构建成功，获取Release下载链接
                    $releaseUrl = 'https://api.github.com/repos/' . $buildInfo['repo_name'] . '/releases/latest';
                    $releaseResult = githubApi($releaseUrl, $token);
                    
                    if ($releaseResult['code'] === 200) {
                        $assets = $releaseResult['data']['assets'] ?? [];
                        $downloadUrl = '';
                        $iosDownloadUrl = '';
                        
                        foreach ($assets as $asset) {
                            $assetName = $asset['name'] ?? '';
                            $assetUrl = $asset['browser_download_url'] ?? '';
                            if (stripos($assetName, 'android') !== false || stripos($assetName, '.apk') !== false) {
                                $downloadUrl = $assetUrl;
                            } elseif (stripos($assetName, 'ios') !== false || stripos($assetName, '.ipa') !== false) {
                                $iosDownloadUrl = $assetUrl;
                            }
                        }
                        
                        \think\Db::name('cloud_build')->where('build_id', $buildId)->update([
                            'status' => 'success',
                            'download_url' => $downloadUrl,
                            'ios_download_url' => $iosDownloadUrl,
                            'finish_time' => time(),
                        ]);
                        
                        $buildInfo['status'] = 'success';
                        $buildInfo['download_url'] = $downloadUrl;
                        $buildInfo['ios_download_url'] = $iosDownloadUrl;
                    }
                } else {
                    \think\Db::name('cloud_build')->where('build_id', $buildId)->update([
                        'status' => 'failed',
                        'finish_time' => time(),
                    ]);
                    $buildInfo['status'] = 'failed';
                }
            }
        }
    }
    
    echo json_encode([
        'code' => 1,
        'msg' => 'success',
        'data' => [
            'build_id' => $buildInfo['build_id'],
            'status' => $buildInfo['status'],
            'app_name' => $buildInfo['app_name'],
            'app_version' => $buildInfo['app_version'],
            'build_platform' => $buildInfo['build_platform'] ?? 'android',
            'download_url' => $buildInfo['download_url'] ?? '',
            'ios_download_url' => $buildInfo['ios_download_url'] ?? '',
            'create_time' => date('Y-m-d H:i:s', $buildInfo['create_time']),
            'finish_time' => $buildInfo['finish_time'] ? date('Y-m-d H:i:s', $buildInfo['finish_time']) : '',
        ]
    ]);
    exit;
}

// [接口3] 获取构建历史
if ($ac == 'buildHistory') {
    $page = intval($_REQUEST['page'] ?? 1);
    $limit = intval($_REQUEST['limit'] ?? 10);
    
    $list = \think\Db::name('cloud_build')
        ->order('id desc')
        ->page($page, $limit)
        ->select();
    
    $total = \think\Db::name('cloud_build')->count();
    
    $data = [];
    foreach ($list as $v) {
        $data[] = [
            'build_id' => $v['build_id'],
            'app_name' => $v['app_name'],
            'app_version' => $v['app_version'],
            'status' => $v['status'],
            'build_platform' => $v['build_platform'] ?? 'android',
            'download_url' => $v['download_url'] ?? '',
            'create_time' => date('Y-m-d H:i:s', $v['create_time']),
        ];
    }
    
    echo json_encode([
        'code' => 1,
        'msg' => 'success',
        'data' => [
            'list' => $data,
            'total' => $total,
            'page' => $page,
        ]
    ]);
    exit;
}

// [接口4] 获取包名和版本信息（供前端展示）
if ($ac == 'getPackageInfo') {
    $cmsConfig = \think\Db::name('config')->where('group', 'getapp')->column('value', 'name');
    
    $hostParts = explode('.', $host);
    $hostParts = array_reverse($hostParts);
    $domainPrefix = isset($hostParts[1]) ? $hostParts[1] : 'app';
    $domainMain = isset($hostParts[2]) ? $hostParts[2] : 'com';
    $autoPackageName = 'com.' . $domainMain . '.' . $domainPrefix . '.app';
    
    $packageName = !empty($cmsConfig['package_name']) ? $cmsConfig['package_name'] : $autoPackageName;
    $appVersion = ''; // 版本号由用户在前端手动输入，此处只返回包名
    
    echo json_encode([
        'code' => 1,
        'msg' => 'success',
        'data' => [
            'package_name' => $packageName,
            'app_version' => $appVersion,
            'api_base_url' => $baseUrl . '/ys_movie_app/backend/app_api.php',
        ]
    ]);
    exit;
}

echo json_encode(['code' => 0, 'msg' => '未知操作']);
