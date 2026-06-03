-- 开发者：杰哥网络科技 (qq: 2711793818)
-- 功能：云端打包系统数据库表结构
-- 说明：需要在MacCMS数据库中执行此SQL创建构建记录表

CREATE TABLE IF NOT EXISTS `mac_cloud_build` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `build_id` varchar(50) NOT NULL DEFAULT '',
  `repo_name` varchar(255) NOT NULL DEFAULT '',
  `app_name` varchar(100) NOT NULL DEFAULT '',
  `package_name` varchar(100) NOT NULL DEFAULT '',
  `app_version` varchar(20) NOT NULL DEFAULT '',
  `api_base_url` varchar(255) NOT NULL DEFAULT '',
  `icon_url` varchar(255) DEFAULT '',
  `splash_url` varchar(255) DEFAULT '',
  `build_platform` enum('android','ios','all') NOT NULL DEFAULT 'android',
  `status` enum('building','success','failed') NOT NULL DEFAULT 'building',
  `download_url` varchar(500) DEFAULT '',
  `ios_download_url` varchar(500) DEFAULT '',
  `github_username` varchar(100) DEFAULT '',
  `create_time` int(11) NOT NULL DEFAULT 0,
  `finish_time` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `build_id` (`build_id`),
  KEY `status` (`status`),
  KEY `create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='云端打包构建记录表';
