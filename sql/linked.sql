create table if not exists links (
       `id`      int(11) NOT NULL AUTO_INCREMENT,
       `user_id` int(11) NOT NULL,
       `provider` VARCHAR(40) NOT NULL,
       `data`    TEXT NOT NULL,
       PRIMARY KEY ( `id` ),
       CONSTRAINT `fk_links_users1`
              FOREIGN KEY (`user_id` ) REFERENCES `users` ( `id` )
	      ON DELETE CASCADE ON UPDATE CASCADE
)

