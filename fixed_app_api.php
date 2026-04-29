<?php
/**
 * 狐狸影视APP专用后端接口 (修复版)
 * 适配 MacCMS 10 目录结构，修复 "Undefined db type" 错误
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');

// 定义应用目录常量
define('ROOT_PATH', __DIR__ . '/');
define('APP_PATH', __DIR__ . '/application/');

// 引入 ThinkPHP 基础文件
if (file_exists(__DIR__ . '/thinkphp/base.php')) {
    require __DIR__ . '/thinkphp/base.php';
} else {
    echo json_encode(['code' => 0, 'msg' => '错误：找不到 thinkphp/base.php']);
    exit;
}

// 手动初始化环境
try {
    // 1. 加载基础配置
    \think\Config::load(APP_PATH . 'config.php');
    
    // 2. 修复：正确加载数据库配置
    // Config::load 加载文件后可能没有正确合并到 database 作用域
    // 这里手动读取并设置
    $dbConfig = include APP_PATH . 'database.php';
    \think\Config::set('database', $dbConfig);
    
    // 3. 加载公共函数
    if (file_exists(APP_PATH . 'common.php')) {
        include APP_PATH . 'common.php';
    }
} catch (\Exception $e) {
    echo json_encode(['code' => 0, 'msg' => '初始化失败: ' . $e->getMessage()]);
    exit;
}

$ac = $_REQUEST['ac'] ?? '';

// 辅助函数
function get_request_param($key, $default = '') {
    return $_REQUEST[$key] ?? $default;
}

function mac_url_img_proxy($url) {
    if (function_exists('mac_url_img')) return mac_url_img($url);
    if (strpos($url, 'http') === 0) return $url;
    $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';
    return $http_type . $_SERVER['HTTP_HOST'] . '/' . ltrim($url, '/');
}

// ================= 接口逻辑 =================

// [接口 1] APP 初始化
if ($ac == 'init') {
    $data = ['code' => 1, 'msg' => 'success'];
    try {
        // 热搜
        $maccms = config('maccms');
        $hot = $maccms['app']['search_hot'] ?? '繁花,庆余年,斗破苍穹';
        $data['hot_search_list'] = array_filter(explode(',', str_replace('，', ',', $hot)));

        // 轮播 (Level 9)
        $data['banner_list'] = \think\Db::name('vod')->where('vod_status', 1)->where('vod_level', 9)->limit(5)->order('vod_hits desc')->field('vod_id,vod_name,vod_pic,vod_pic_slide,vod_remarks,type_id')->select();
        foreach ($data['banner_list'] as &$v) {
            $v['vod_pic'] = mac_url_img_proxy($v['vod_pic_slide'] ?: $v['vod_pic']);
            $v['type_name'] = \think\Db::name('type')->where('type_id', $v['type_id'])->value('type_name');
        }

        // 推荐 (Level 8)
        $data['recommend_list'] = \think\Db::name('vod')->where('vod_status', 1)->where('vod_level', 8)->limit(10)->order('vod_hits desc')->field('vod_id,vod_name,vod_pic,vod_remarks,vod_score,vod_year')->select();
        foreach ($data['recommend_list'] as &$v) $v['vod_pic'] = mac_url_img_proxy($v['vod_pic']);

        // 分类推荐
        $data['type_recommend_list'] = [];
        foreach ([1=>'电影',2=>'电视剧',3=>'综艺',4=>'动漫'] as $tid=>$name) {
            $list = \think\Db::name('vod')->where('vod_status', 1)->where('type_id', $tid)->limit(6)->order('vod_time desc')->field('vod_id,vod_name,vod_pic,vod_remarks,vod_score,vod_year')->select();
            foreach ($list as &$v) $v['vod_pic'] = mac_url_img_proxy($v['vod_pic']);
            if($list) $data['type_recommend_list'][] = ['type_id'=>$tid, 'type_name'=>$name, 'list'=>$list];
        }

        // 全部分类列表
        $data['type_list'] = \think\Db::name('type')->where('type_status', 1)->order('type_sort asc')->field('type_id,type_name,type_pid')->select();
    } catch (\Exception $e) {
        $data['msg'] = $e->getMessage();
    }
    echo json_encode($data);
    exit;
}

// [接口 2] 高级筛选 (list)
if ($ac == 'list') {
    $type_id = get_request_param('t');
    $class = get_request_param('class');
    $area = get_request_param('area');
    $lang = get_request_param('lang');
    $year = get_request_param('year');
    $by = get_request_param('by', 'time');
    $page = get_request_param('pg', 1);
    $limit = get_request_param('pagesize', 20);

    $where = ['vod_status' => 1];
    
    try {
        if ($type_id) {
            $type = \think\Db::name('type')->where('type_id', $type_id)->find();
            if ($type && $type['type_pid'] == 0) $where['type_id_1'] = $type_id;
            else $where['type_id'] = $type_id;
        }
        
        // 筛选逻辑
        if ($class && $class != '全部') $where['vod_class'] = ['like', "%$class%"];
        if ($area && $area != '全部') $where['vod_area'] = ['like', "%$area%"];
        if ($lang && $lang != '全部') $where['vod_lang'] = ['like', "%$lang%"];
        if ($year && $year != '全部') $where['vod_year'] = $year;

        // 排序
        $order = 'vod_time desc';
        if ($by == 'hits') $order = 'vod_hits desc';
        if ($by == 'score') $order = 'vod_score desc';
        if (strpos($by, 'hits_') !== false) $order = 'vod_' . $by . ' desc';

        $list = \think\Db::name('vod')->where($where)->order($order)->page($page, $limit)->field('vod_id,vod_name,vod_pic,vod_remarks,vod_score,vod_year,vod_actor')->select();
        foreach ($list as &$v) $v['vod_pic'] = mac_url_img_proxy($v['vod_pic']);

        echo json_encode(['code' => 1, 'list' => $list]);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage()]);
    }
    exit;
}

// [接口 3] 搜索
if ($ac == 'search') {
    $wd = get_request_param('wd');
    $page = get_request_param('pg', 1);
    $limit = get_request_param('pagesize', 20);
    $where = ['vod_status' => 1, 'vod_name' => ['like', "%$wd%"]];
    try {
        $list = \think\Db::name('vod')->where($where)->order('vod_time desc')->page($page, $limit)->field('vod_id,vod_name,vod_pic,vod_remarks,vod_score,vod_year')->select();
        foreach ($list as &$v) $v['vod_pic'] = mac_url_img_proxy($v['vod_pic']);
        echo json_encode(['code' => 1, 'list' => $list]);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage()]);
    }
    exit;
}

// [接口 4] 登录
if ($ac == 'login') {
    $name = get_request_param('user_name');
    $pwd = get_request_param('user_pwd');
    // 简单透传逻辑，实际应调用 User 模型
    // 这里仅做示例，建议直接使用 MacCMS 原生接口 /index.php/user/login
    echo json_encode(['code' => 0, 'msg' => '请使用原生登录接口']);
    exit;
}

echo json_encode(['code' => 0, 'msg' => 'API Ready (Fixed Version)']);
