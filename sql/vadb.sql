CREATE TABLE IF NOT EXISTS `sessions` (
   id           CHAR(72) PRIMARY KEY,
   session_data TEXT CHARACTER SET utf8,
   expires      INTEGER
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `roles` (
   `id` int(11) NOT NULL AUTO_INCREMENT,
   `role` text CHARACTER SET utf8,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `users` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `provider` text CHARACTER SET utf8,
    `provider_id` text CHARACTER SET utf8,
    `username` text CHARACTER SET utf8,
    `password` text CHARACTER SET utf8,
    `email` text CHARACTER SET utf8,
    `displayname` text CHARACTER SET utf8,
    `active` VARCHAR(32) DEFAULT NULL,
    `uuid` VARCHAR(40) DEFAULT NULL,
    `accepted_terms` VARCHAR(32) DEFAULT NULL,
     PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `pending_users` (
    `email` VARCHAR(64) CHARACTER SET utf8 NOT NULL,
    `password` TEXT CHARACTER SET utf8 NOT NULL,
    `username` text CHARACTER SET utf8 DEFAULT NULL,
    `code` TEXT CHARACTER SET utf8 NOT NULL,
    `active` VARCHAR(32) DEFAULT NULL,
    PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `password_resets` (
    `email` VARCHAR(64) CHARACTER SET utf8 NOT NULL,
    `code` TEXT CHARACTER SET utf8 NOT NULL,
    PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_roles` (
    `user_id` int(11) NOT NULL DEFAULT '0',
    `role_id` int(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`user_id`,`role_id`),
    KEY `role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `mediafiles` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `filename` text,
    `uuid` VARCHAR(40) DEFAULT NULL,
    `user_id` int(11) NOT NULL DEFAULT '0',
    `type` VARCHAR(40) NOT NULL DEFAULT 'original',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `views` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `uuid` VARCHAR(40) DEFAULT NULL,
    `filename` text,
    `uri` text,
    `mimetype` VARCHAR(64) NOT NULL,
    `size` int(11) not null default '0',
    `location` VARCHAR(28) not null default 'fp',
    `type` VARCHAR(28) NOT NULL DEFAULT 'main',
    `mediafile_id` int(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `workorders` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` text,
    `state` varchar(24) NOT NULL DEFAULT 'WO_NEW',
    `uuid` VARCHAR(40) DEFAULT NULL,
    `user_id` int(11) NOT NULL DEFAULT '0',
    `submitted` VARCHAR(32) DEFAULT NULL,
    `completed` VARCHAR(32) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `mediafile_workorders` (
    `mediafile_id` int(11) NOT NULL DEFAULT '0',
    `workorder_id` int(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`mediafile_id`,`workorder_id`),
    KEY `workorder_id` (`workorder_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Add foreign key constraints last, so the order of table
-- definition doesn't matter.
--

-- User Roles
--

ALTER TABLE `user_roles`
   ADD CONSTRAINT `user_role_ibfk_2` 
     FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE,
   ADD CONSTRAINT `user_role_ibfk_1` 
   FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `mediafile_workorders`
   ADD CONSTRAINT `mediafile_workorder_ibfk_2` 
     FOREIGN KEY (`workorder_id`) REFERENCES `workorders` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE,
   ADD CONSTRAINT `mediafile_workorder_ibfk_1` 
   FOREIGN KEY (`mediafile_id`) REFERENCES `mediafiles` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `mediafiles`
   ADD CONSTRAINT `mediafile_ibfk_2` 
     FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `workorders`
   ADD CONSTRAINT `workorder_ibfk_2` 
     FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `views`
   ADD CONSTRAINT `view_ibfk_2` 
     FOREIGN KEY (`mediafile_id`) REFERENCES `mediafiles` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE;

-- Populate roles
--
INSERT INTO `roles` (id, role) VALUES (1, 'admin'), (2, 'dbadmin'), (3, 'instructor' );

