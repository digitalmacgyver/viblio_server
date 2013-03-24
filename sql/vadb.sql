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
    `uuid` text,
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

-- So we can use photos in many other places, there will
-- be no foriegn key, and the id is manually set to the 
-- id of the owner.  A might_have or has_a relationship is
-- set up manually on the table class.
--
CREATE TABLE IF NOT EXISTS `mediafile` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `mimetype` VARCHAR(64) NOT NULL,
    `filename` VARCHAR(64) NOT NULL,
    `path` text,
    `size` int(11) DEFAULT 0,
    `uuid` text,
    `user_id` int(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
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

-- Media
--
ALTER TABLE `mediafile`
   ADD CONSTRAINT `mediafile_ibfk_2` 
     FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) 
     ON DELETE CASCADE ON UPDATE CASCADE;

-- Populate roles
--
INSERT INTO `roles` (id, role) VALUES (1, 'admin'), (2, 'dbadmin'), (3, 'instructor' );

