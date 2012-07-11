CREATE TABLE file 
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	last_updated     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	                           ON UPDATE CURRENT_TIMESTAMP,
	mimetype         VARCHAR(64) NOT NULL,
	hostname         VARCHAR(65) NOT NULL,
	pathname         VARCHAR(256) NOT NULL,
	sha1             CHAR(40) NOT NULL,
	fsize            BIGINT UNSIGNED NOT NULL,
	mtime            INT UNSIGNED NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE audio_file
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	file_id          MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id),
	albumid          CHAR(36) NOT NULL, # musicbrainz id
	artistid         CHAR(36) NOT NULL, # musicbrainz id
	albumartistid    CHAR(36) NOT NULL, # musicbrainz id
	trackid          CHAR(36) NOT NULL, # musicbrainz id
	PRIMARY KEY (id)
);

CREATE TABLE flac_file
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	audiofile_id     MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES audio_file(id),
	flaccomments_id  MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES flac_comments(id),
	flacstream_id    MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES flac_stream(id),
	PRIMARY KEY (id)
);

CREATE TABLE flac_comments
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	title            VARCHAR(255),
	artist           VARCHAR(255),
	artistsort       VARCHAR(255),
	album            VARCHAR(255),
	tracknumber      TINYINT UNSIGNED,
	totaltracks      TINYINT UNSIGNED,
	PRIMARY KEY (id)
);

CREATE TABLE flac_stream
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	total_samples    INT UNSIGNED NOT NULL,
	sample_rate      MEDIUMINT UNSIGNED NOT NULL,
	channels         TINYINT UNSIGNED NOT NULL,
	bits_per_sample  TINYINT UNSIGNED NOT NULL,
	MD5_signature    CHAR(32) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE iso_metadata
(
	id               SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	file_id          MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id),
	software         VARCHAR(255) NOT NULL,
	used_options     VARCHAR(255) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE archive
(
	last_updated     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	                           ON UPDATE CURRENT_TIMESTAMP,
	archiver         MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id),
	archived         MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id),
	archived_suffix  VARCHAR(255) NOT NULL
);

CREATE TABLE dvd
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	last_updated     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	                           ON UPDATE CURRENT_TIMESTAMP,
	image_file       MEDIUMINT UNSIGNED NOT NULL
	                          REFERENCES file(id),
	dvd_type         VARCHAR(10) NOT NULL,
	dvd_trademark    VARCHAR(30) NOT NULL,
	on_loan_to       VARCHAR(36) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE par2create 
(
	session_id       MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	ctime            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	software         VARCHAR(255) NOT NULL,
	blocksize        MEDIUMINT UNSIGNED NOT NULL,
	blockcount       MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (session_id)
);

CREATE TABLE par2create_target 
(
	session          MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES par2create(session_id),
	target           MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id)
);

CREATE TABLE par2create_volset 
(
	session          MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES par2create(session_id),
	volume_set       MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id)
);

CREATE TABLE container_file
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	file_id          MEDIUMINT UNSIGNED NOT NULL
	                           REFERENCES file(id),
	format_name      VARCHAR(10) NOT NULL,
	format_long_name VARCHAR(36) NOT NULL,
	start_time       DECIMAL NOT NULL,
	duration         DECIMAL NOT NULL,
	bit_rate         MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (id)
);
