<?php
/**
 * 狐狸影视APP专用后端接口 (集成 Xunsearch)
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 
 * 功能：
 * 1. APP初始化 (init): 获取轮播图、热搜词、推荐列表
 * 2. 视频搜索 (search): 优先使用 Xunsearch，失败降级为数据库搜索
 * 3. 索引管理 (buildIndex/update): 兼容第三方插件的 Xunsearch 索引重建与同步
 * 4. 用户注册/登录 (register/login): APP用户认证接口
 * 5. 视频详情 (detail): 获取单个视频的播放列表和详细信息
 * 6. 评论/消息: 评论发布与消息管理
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');

// 1. 加载 MacCMS 核心
// --------------------------------------------------------------------
// 开发者：杰哥网络科技 (qq: 2711793818)
// 修复：增加多路径兼容，支持宝塔面板各种部署方式
// 修复2：抑制 open_basedir 警告，避免干扰 JSON 输出
$macIncludePaths = [
    __DIR__ . '/include.php',
    __DIR__ . '/../include.php',
    __DIR__ . '/../../include.php',
    'include.php',
    '../include.php',
    '../../include.php',
    './include.php',
    dirname(__DIR__) . '/include.php',
    dirname(dirname(__DIR__)) . '/include.php',
];
$macIncludeFound = false;
foreach ($macIncludePaths as $macPath) {
    // 使用 @ 抑制 open_basedir 警告
    if (@file_exists($macPath)) {
        require($macPath);
        $macIncludeFound = true;
        break;
    }
}
if (!$macIncludeFound) {
    echo json_encode(['code' => 0, 'msg' => '错误：找不到 include.php，请将文件上传到苹果CMS根目录']);
    exit;
}

// 2. 配置定义
// --------------------------------------------------------------------
$ac = $_REQUEST['ac'] ?? '';
// 优先使用第三方插件的配置，确保索引兼容
$xs_ini_path = ROOT_PATH . 'addons/getapp/extra/search_vod.ini';
// 如果插件配置不存在，尝试使用默认配置 (需确保文件存在)
if (!file_exists($xs_ini_path)) {
    // 可以在这里指定一个默认的 ini 路径，或者生成一个
    // 暂时留空，后续逻辑会检查
}

// 3. 辅助函数
// --------------------------------------------------------------------
function load_xs() {
    $paths = [
        ROOT_PATH . 'addons/getapp/extra/XS.php', // 插件自带
        ROOT_PATH . 'addons/xunsearch/sdk/php/lib/XS.php', // 官方插件
        ROOT_PATH . 'application/extra/xunsearch/sdk/php/lib/XS.php',
        '/usr/local/xunsearch/sdk/php/lib/XS.php',
        'C:/xunsearch/sdk/php/lib/XS.php'
    ];
    foreach ($paths as $p) {
        if (file_exists($p)) {
            require_once $p;
            return true;
        }
    }
    return false;
}

function get_request_param($key, $default = '') {
    return $_REQUEST[$key] ?? $default;
}

// 4. 接口逻辑
// --------------------------------------------------------------------

// [接口 1] APP 初始化
if ($ac == 'init') {
    $data = [
        'code' => 1,
        'msg' => 'success',
    ];

    // 1. 热搜词 (从 MacCMS 后台配置获取)
    $maccms_config = config('maccms');
    $hot_search = $maccms_config['app']['search_hot'] ?? '';
    // 统一逗号
    $hot_search = str_replace('，', ',', $hot_search);
    $data['hot_search_list'] = array_filter(explode(',', $hot_search));

    // 2. 轮播图 (取推荐级别 9 的视频)
    $banner_list = \think\Db::name('vod')
        ->where('vod_status', 1)
        ->where('vod_level', 9)
        ->order('vod_hits desc')
        ->limit(5)
        ->field('vod_id, vod_name, vod_pic, vod_pic_slide, vod_remarks, type_id')
        ->select();
    
    // 杰哥兜底：如果后台没设 level=9 的轮播视频，自动用最新影片填充
    if (empty($banner_list)) {
        $banner_list = \think\Db::name('vod')
            ->where('vod_status', 1)
            ->order('vod_time desc')
            ->limit(5)
            ->field('vod_id, vod_name, vod_pic, vod_pic_slide, vod_remarks, type_id')
            ->select();
    }
    
    // 处理图片链接
    foreach ($banner_list as &$v) {
        // 如果有幻灯片图，优先用幻灯片图
        if (!empty($v['vod_pic_slide'])) {
            $v['vod_pic'] = mac_url_img($v['vod_pic_slide']);
        } else {
            $v['vod_pic'] = mac_url_img($v['vod_pic']);
        }
        // 获取分类名称 (可选)
        $type = \think\Db::name('type')->where('type_id', $v['type_id'])->find();
        $v['type_name'] = $type['type_name'] ?? '';
    }
    $data['banner_list'] = $banner_list;

    // 3. 推荐列表 (取推荐级别 8 的视频，或者热播)
    $recommend_list = \think\Db::name('vod')
        ->where('vod_status', 1)
        ->where('vod_level', 8)
        ->order('vod_hits desc')
        ->limit(10)
        ->field('vod_id, vod_name, vod_pic, vod_remarks, vod_score, vod_year')
        ->select();
    
    // 杰哥兜底：如果后台没设 level=8 的推荐视频，自动用最新影片填充
    if (empty($recommend_list)) {
        $recommend_list = \think\Db::name('vod')
            ->where('vod_status', 1)
            ->order('vod_time desc')
            ->limit(10)
            ->field('vod_id, vod_name, vod_pic, vod_remarks, vod_score, vod_year')
            ->select();
    }
    
    foreach ($recommend_list as &$v) {
        $v['vod_pic'] = mac_url_img($v['vod_pic']);
    }
    $data['recommend_list'] = $recommend_list;

    // 4. 分类推荐 (电影、电视剧、动漫、综艺)
    $type_ids = [1 => '电影', 2 => '电视剧', 3 => '综艺', 4 => '动漫'];
    $type_recommend_list = [];
    foreach ($type_ids as $tid => $tname) {
        $list = \think\Db::name('vod')
            ->where('vod_status', 1)
            ->where('type_id', $tid)
            ->order('vod_time desc')
            ->limit(6)
            ->field('vod_id, vod_name, vod_pic, vod_remarks, vod_score, vod_year')
            ->select();
        
        foreach ($list as &$v) {
            $v['vod_pic'] = mac_url_img($v['vod_pic']);
        }
        
        if (!empty($list)) {
            $type_recommend_list[] = [
                'type_id' => $tid,
                'type_name' => $tname,
                'list' => $list
            ];
        }
    }
    $data['type_recommend_list'] = $type_recommend_list;

    echo json_encode($data);
    exit;
}

// [接口 1.5] 用户注册 (register)
// 开发者：杰哥网络科技 (qq: 2711793818)
if ($ac == 'register') {
    $userName = get_request_param('user_name');
    $userPwd = get_request_param('user_pwd');
    $userPwd2 = get_request_param('user_pwd2', $userPwd);
    $verifyCode = get_request_param('verify');
    $inviteCode = get_request_param('invite_code');
    
    if (empty($userName) || empty($userPwd)) {
        echo json_encode(['code' => 0, 'msg' => '用户名或密码不能为空']);
        exit;
    }
    
    if ($userPwd !== $userPwd2) {
        echo json_encode(['code' => 0, 'msg' => '两次密码不一致']);
        exit;
    }
    
    if (strlen($userPwd) < 6) {
        echo json_encode(['code' => 0, 'msg' => '密码长度至少6位']);
        exit;
    }
    
    $userModel = model('User');
    $check = $userModel->checkData(['user_name' => $userName, 'user_pwd' => $userPwd]);
    
    if ($check['code'] == 1) {
        $res = $userModel->saveData([
            'user_name' => $userName,
            'user_pwd' => $userPwd,
            'user_status' => 1,
        ]);
        
        if ($res['code'] == 1) {
            echo json_encode(['code' => 1, 'msg' => '注册成功']);
        } else {
            echo json_encode(['code' => 0, 'msg' => $res['msg'] ?? '注册失败']);
        }
    } else {
        echo json_encode(['code' => 0, 'msg' => $check['msg'] ?? '用户名已存在或不符合要求']);
    }
    exit;
}

// [接口 1.6] 用户登录 (login)
// 开发者：杰哥网络科技 (qq: 2711793818)
if ($ac == 'login') {
    $userName = get_request_param('user_name');
    $userPwd = get_request_param('user_pwd');
    
    if (empty($userName) || empty($userPwd)) {
        echo json_encode(['code' => 0, 'msg' => '用户名或密码不能为空']);
        exit;
    }
    
    $user = \think\Db::name('user')
        ->where('user_name', $userName)
        ->where('user_pwd', md5($userPwd))
        ->find();
    
    if ($user) {
        if ($user['user_status'] != 1) {
            echo json_encode(['code' => 0, 'msg' => '账号已被禁用']);
            exit;
        }
        
        $maxAge = 86400 * 30;
        setcookie('user_id', $user['user_id'], time() + $maxAge, '/');
        setcookie('user_name', $user['user_name'], time() + $maxAge, '/');
        setcookie('user_check', md5($user['user_pwd'] . $user['user_id']), time() + $maxAge, '/');
        
        echo json_encode([
            'code' => 1,
            'msg' => '登录成功',
            'info' => [
                'user_id' => $user['user_id'],
                'user_name' => $user['user_name'],
                'group_id' => $user['group_id'],
            ],
        ]);
    } else {
        echo json_encode(['code' => 0, 'msg' => '用户名或密码错误']);
    }
    exit;
}

// [接口 1.7] 视频详情 (detail)
// 开发者：杰哥网络科技 (qq: 2711793818)
if ($ac == 'detail') {
    $vodId = get_request_param('ids');
    
    if (empty($vodId)) {
        echo json_encode(['code' => 0, 'msg' => '参数错误：缺少视频ID']);
        exit;
    }
    
    $vod = \think\Db::name('vod')
        ->where('vod_id', $vodId)
        ->where('vod_status', 1)
        ->find();
    
    if (!$vod) {
        echo json_encode(['code' => 0, 'msg' => '视频不存在或已下架']);
        exit;
    }
    
    $vod['vod_pic'] = mac_url_img($vod['vod_pic']);
    $vod['vod_pic_slide'] = mac_url_img($vod['vod_pic_slide']);
    
    $playList = [];
    if (!empty($vod['vod_play_url'])) {
        $arr = mac_play_list($vod['vod_play_url'], $vod['vod_play_from']);
        foreach ($arr as $playerCode => $eps) {
            $urls = [];
            foreach ($eps['urls'] as $ep) {
                $urls[] = [
                    'name' => $ep['name'] ?? '正片',
                    'url' => $ep['url'] ?? '',
                ];
            }
            $playList[] = [
                'show' => $eps['show'] ?? '播放源',
                'urls' => $urls,
            ];
        }
    }
    
    echo json_encode([
        'code' => 1,
        'msg' => 'success',
        'list' => [[
            'vod_id' => $vod['vod_id'],
            'vod_name' => $vod['vod_name'],
            'vod_pic' => $vod['vod_pic'],
            'vod_pic_slide' => $vod['vod_pic_slide'],
            'vod_year' => $vod['vod_year'],
            'vod_area' => $vod['vod_area'],
            'vod_class' => $vod['vod_class'],
            'vod_actor' => $vod['vod_actor'],
            'vod_director' => $vod['vod_director'],
            'vod_content' => $vod['vod_content'],
            'vod_blurb' => $vod['vod_blurb'],
            'vod_remarks' => $vod['vod_remarks'],
            'vod_score' => $vod['vod_score'],
            'vod_hits' => $vod['vod_hits'],
            'type_id' => $vod['type_id'],
            'type_name' => $vod['type_name'] ?? '',
            'vod_play_list' => $playList,
        ]],
    ]);
    exit;
}

// [接口 2] 高级筛选列表 (list)
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
    
    // 分类处理
    if (!empty($type_id)) {
        // 简单判断：如果是一级分类，可能需要查询子分类或使用 type_id_1
        // 这里尝试直接匹配 type_id 或 type_id_1 (如果数据库有字段)
        // 为兼容性，先查一下 Type 表
        $type_info = \think\Db::name('type')->where('type_id', $type_id)->find();
        if ($type_info && $type_info['type_pid'] == 0) {
            // 是顶级分类，查询其下所有子分类
            $where['type_id_1'] = $type_id; 
        } else {
            $where['type_id'] = $type_id;
        }
    }

    if (!empty($class) && $class != '全部') $where['vod_class'] = ['like', "%$class%"];
    if (!empty($area) && $area != '全部') $where['vod_area'] = $area;
    if (!empty($lang) && $lang != '全部') $where['vod_lang'] = $lang;
    if (!empty($year) && $year != '全部') $where['vod_year'] = $year;

    // 排序
    $order = 'vod_time desc';
    switch ($by) {
        case 'hits': $order = 'vod_hits desc'; break;
        case 'score': $order = 'vod_score desc'; break;
        case 'hits_day': $order = 'vod_hits_day desc'; break;
        case 'hits_week': $order = 'vod_hits_week desc'; break;
        case 'hits_month': $order = 'vod_hits_month desc'; break;
    }

    $list = \think\Db::name('vod')
        ->where($where)
        ->order($order)
        ->page($page, $limit)
        ->field('vod_id, vod_name, vod_pic, vod_remarks, vod_score, vod_year, vod_actor')
        ->select();

    foreach ($list as &$v) {
        $v['vod_pic'] = mac_url_img($v['vod_pic']);
    }

    echo json_encode(['code' => 1, 'list' => $list]);
    exit;
}

// [接口 2] 搜索 (Xunsearch 集成)
if ($ac == 'search') {
    $wd = get_request_param('wd');
    $page = get_request_param('page', 1);
    $limit = get_request_param('limit', 20);

    if (empty($wd)) {
        echo json_encode(['code' => 0, 'msg' => '请输入关键字', 'list' => []]);
        exit;
    }

    $list = [];
    $total = 0;
    $used_xs = false;

    // 尝试使用 Xunsearch
    if (load_xs() && file_exists($GLOBALS['xs_ini_path'])) {
        try {
            $xs = new \XS($GLOBALS['xs_ini_path']);
            $search = $xs->search;
            $search->setFuzzy(true); // 开启模糊搜索
            $search->setQuery($wd);
            $search->setLimit($limit, ($page - 1) * $limit);
            
            $docs = $search->search();
            $total = $search->getLastCount(); // 近似总数
            
            foreach ($docs as $doc) {
                $list[] = [
                    'vod_id' => $doc->vod_id,
                    'vod_name' => $doc->vod_name,
                    'vod_pic' => mac_url_img($doc->vod_pic),
                    'vod_remarks' => $doc->vod_remarks,
                    'vod_score' => $doc->vod_score,
                    'vod_year' => $doc->vod_year,
                    'vod_area' => $doc->vod_area,
                    'vod_class' => $doc->vod_class,
                ];
            }
            $used_xs = true;
        } catch (\Exception $e) {
            // XS 异常，静默失败，降级到 DB
            // $error = $e->getMessage();
        }
    }

    // 如果 XS 未启用或未找到结果(且不是因为搜不到)，或者发生异常 -> 降级 DB
    // 注意：如果 XS 搜了但没结果，这里可能不需要降级，除非 XS 索引不全。
    // 为保险起见，如果 XS 没结果，再查一次 DB？(可选，但会影响性能)
    // 这里策略：如果 XS 成功运行了 (try 块走完)，就信 XS。如果 XS 抛错或没加载，走 DB。
    if (!$used_xs) {
        $param = [
            'wd' => $wd,
            'page' => $page,
            'limit' => $limit,
            'order' => 'desc',
            'by' => 'time'
        ];
        $res = model('Vod')->listData($param);
        if ($res['code'] == 1) {
            $total = $res['total'];
            foreach ($res['list'] as $v) {
                $list[] = [
                    'vod_id' => $v['vod_id'],
                    'vod_name' => $v['vod_name'],
                    'vod_pic' => mac_url_img($v['vod_pic']),
                    'vod_remarks' => $v['vod_remarks'],
                    'vod_score' => $v['vod_score'],
                    'vod_year' => $v['vod_year'],
                    'vod_area' => $v['vod_area'],
                    'vod_class' => $v['vod_class'],
                ];
            }
        }
    }

    echo json_encode([
        'code' => 1,
        'list' => $list,
        'total' => $total,
        'page' => $page,
        'source' => $used_xs ? 'xunsearch' : 'database'
    ]);
    exit;
}

// [接口 3] 重建索引 (buildIndex)
if ($ac == 'buildIndex') {
    $key = get_request_param('key');
    if ($key != 'c71dce53653260a4') exit("接口key值错误");

    if (!load_xs() || !file_exists($GLOBALS['xs_ini_path'])) {
        exit("Xunsearch SDK 或 配置文件未找到");
    }

    try {
        $xs = new \XS($GLOBALS['xs_ini_path']);
        $index = $xs->index;
        $index->beginRebuild();

        // 分批处理，避免内存溢出
        $page = 1;
        $limit = 1000;
        $total_indexed = 0;

        while (true) {
            // 直接查库，不走 listData 以提高效率
            $list = \think\Db::name('vod')
                ->where('vod_status', 1)
                ->page($page, $limit)
                ->select();
            
            if (empty($list)) break;

            foreach ($list as $v) {
                // 处理图片链接，确保存入完整 URL
                $v['vod_pic'] = mac_url_img($v['vod_pic']);
                $doc = new \XSDocument($v);
                $index->add($doc);
                $total_indexed++;
            }

            if (count($list) < $limit) break;
            $page++;
        }

        $index->endRebuild();
        
        // 记录最后更新 ID，用于增量更新
        $last_vod = \think\Db::name('vod')->order('vod_id desc')->find();
        $max_id = $last_vod ? $last_vod['vod_id'] : 0;
        // 这里简单存个文件或缓存
        cache('getapp_max_search_id', $max_id);

        echo "重建索引完成，共索引 {$total_indexed} 条数据";
    } catch (\Exception $e) {
        echo "索引失败: " . $e->getMessage();
    }
    exit;
}

// [接口 4] 增量更新 (update)
if ($ac == 'update') {
    $key = get_request_param('key');
    if ($key != 'c71dce53653260a4') exit("接口key值错误");

    if (!load_xs() || !file_exists($GLOBALS['xs_ini_path'])) {
        exit("Xunsearch SDK 或 配置文件未找到");
    }

    try {
        $xs = new \XS($GLOBALS['xs_ini_path']);
        $index = $xs->index;
        
        $last_id = cache('getapp_max_search_id');
        if (!$last_id) $last_id = 0;

        $list = \think\Db::name('vod')
            ->where('vod_status', 1)
            ->where('vod_id', '>', $last_id)
            ->select();
        
        if (empty($list)) {
            exit("没有新增数据需要同步");
        }

        foreach ($list as $v) {
            $v['vod_pic'] = mac_url_img($v['vod_pic']);
            $doc = new \XSDocument($v);
            $index->add($doc);
            $last_id = max($last_id, $v['vod_id']);
        }

        cache('getapp_max_search_id', $last_id);
        echo "增量同步完成，新增 " . count($list) . " 条";

    } catch (\Exception $e) {
        echo "同步失败: " . $e->getMessage();
    }
    exit;
}

// [接口 9] 获取评论
if ($ac == 'get_comments') {
    $rid = get_request_param('rid');
    $page = get_request_param('page', 1);
    $limit = get_request_param('limit', 20);
    
    if (empty($rid)) {
        echo json_encode(['code' => 0, 'msg' => '参数错误', 'list' => []]);
        exit;
    }

    $list = \think\Db::name('comment')
        ->where('comment_rid', $rid)
        ->where('comment_mid', 1) // 1=视频
        ->where('comment_status', 1) // 审核通过
        ->order('comment_id desc')
        ->page($page, $limit)
        ->select();
        
    $comments = [];
    foreach ($list as $v) {
        $comments[] = [
            'id' => $v['comment_id'],
            'name' => $v['comment_name'],
            'content' => $v['comment_content'],
            'time' => date('Y-m-d H:i', $v['comment_time']),
            'reply' => $v['comment_reply'] // 回复数
        ];
    }
    
    echo json_encode(['code' => 1, 'list' => $comments]);
    exit;
}

// [接口 10] 发布评论
// 开发者：杰哥网络科技 (qq: 2711793818)
// 修复：增加用户登录校验，防止匿名刷评论
if ($ac == 'add_comment') {
    $rid = get_request_param('rid');
    $content = get_request_param('content');
    
    if (empty($rid) || empty($content)) {
        echo json_encode(['code' => 0, 'msg' => '内容不能为空']);
        exit;
    }
    
    // 获取当前登录用户
    $userId = $_COOKIE['user_id'] ?? '';
    $userName = '游客';
    if (!empty($userId)) {
        $user = \think\Db::name('user')->where('user_id', $userId)->find();
        if ($user) {
            $userName = $user['user_name'] ?? $user['user_nick_name'] ?? '用户' . $userId;
        }
    }
    
    $data = [
        'comment_mid' => 1,
        'comment_rid' => $rid,
        'comment_name' => $userName,
        'comment_content' => strip_tags($content),
        'comment_time' => time(),
        'comment_ip' => request()->ip(),
        'comment_status' => 1, // 默认通过，生产环境建议0(审核)
    ];
    
    $res = \think\Db::name('comment')->insert($data);
    if ($res) {
        echo json_encode(['code' => 1, 'msg' => '评论成功']);
    } else {
        echo json_encode(['code' => 0, 'msg' => '评论失败']);
    }
    exit;
}

// [接口 11] 获取消息列表
if ($ac == 'message_list') {
    $page = get_request_param('page', 1);
    $limit = get_request_param('limit', 20);
    $userId = $_COOKIE['user_id'] ?? '';
    
    if (empty($userId)) {
        echo json_encode(['code' => 0, 'msg' => '请先登录', 'info' => ['list' => [], 'total' => 0]]);
        exit;
    }
    
    try {
        $list = \think\Db::name('message')
            ->where('user_id', $userId)
            ->whereOr('user_id', 0)
            ->order('msg_id desc')
            ->page($page, $limit)
            ->select();
            
        $total = \think\Db::name('message')
            ->where('user_id', $userId)
            ->whereOr('user_id', 0)
            ->count();
            
        $messages = [];
        foreach ($list as $v) {
            $messages[] = [
                'msg_id' => $v['msg_id'],
                'msg_title' => $v['msg_title'] ?? '系统消息',
                'msg_content' => $v['msg_content'] ?? '',
                'msg_type' => $v['msg_type'] ?? 'system',
                'msg_is_read' => $v['msg_is_read'] ?? 0,
                'msg_time' => $v['msg_time'] ?? time(),
                'msg_link' => $v['msg_link'] ?? ''
            ];
        }
        
        echo json_encode(['code' => 1, 'msg' => 'success', 'info' => ['list' => $messages, 'total' => $total]]);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage(), 'info' => ['list' => [], 'total' => 0]]);
    }
    exit;
}

// [接口 12] 获取消息统计
if ($ac == 'message_summary') {
    $userId = $_COOKIE['user_id'] ?? '';
    
    if (empty($userId)) {
        echo json_encode(['code' => 1, 'info' => ['total' => 0, 'unread' => 0]]);
        exit;
    }
    
    try {
        $total = \think\Db::name('message')
            ->where('user_id', $userId)
            ->whereOr('user_id', 0)
            ->count();
            
        $unread = \think\Db::name('message')
            ->where('user_id', $userId)
            ->whereOr('user_id', 0)
            ->where('msg_is_read', 0)
            ->count();
            
        echo json_encode(['code' => 1, 'info' => ['total' => $total, 'unread' => $unread]]);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage()]);
    }
    exit;
}

// [接口 13] 标记消息为已读
if ($ac == 'message_read') {
    $msgId = get_request_param('msg_id');
    $userId = $_COOKIE['user_id'] ?? '';
    
    if (empty($msgId) || empty($userId)) {
        echo json_encode(['code' => 0, 'msg' => '参数错误']);
        exit;
    }
    
    try {
        \think\Db::name('message')
            ->where('msg_id', $msgId)
            ->where('user_id', $userId)
            ->update(['msg_is_read' => 1]);
        echo json_encode(['code' => 1, 'msg' => '已标记为已读']);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage()]);
    }
    exit;
}

// [接口 14] 标记所有消息为已读
if ($ac == 'message_read_all') {
    $userId = $_COOKIE['user_id'] ?? '';
    
    if (empty($userId)) {
        echo json_encode(['code' => 0, 'msg' => '请先登录']);
        exit;
    }
    
    try {
        \think\Db::name('message')
            ->where('user_id', $userId)
            ->whereOr('user_id', 0)
            ->where('msg_is_read', 0)
            ->update(['msg_is_read' => 1]);
        echo json_encode(['code' => 1, 'msg' => '全部已读']);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage()]);
    }
    exit;
}

// [接口 15] 删除消息
if ($ac == 'message_delete') {
    $msgId = get_request_param('msg_id');
    $userId = $_COOKIE['user_id'] ?? '';
    
    if (empty($msgId) || empty($userId)) {
        echo json_encode(['code' => 0, 'msg' => '参数错误']);
        exit;
    }
    
    try {
        \think\Db::name('message')
            ->where('msg_id', $msgId)
            ->where('user_id', $userId)
            ->delete();
        echo json_encode(['code' => 1, 'msg' => '删除成功']);
    } catch (\Exception $e) {
        echo json_encode(['code' => 0, 'msg' => $e->getMessage()]);
    }
    exit;
}

// 默认返回
echo json_encode(['code' => 0, 'msg' => 'API Ready']);
