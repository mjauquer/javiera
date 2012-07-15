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
	file             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES file(id),
	type             ENUM('flac', 'mp3', 'ogg') NOT NULL,
	trackid          CHAR(36) NOT NULL, # musicbrainz id
	PRIMARY KEY (id)
);

CREATE TABLE audio_file_tags
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	audio_file       MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES audio_file(id),
	tag              MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES tag(id),
	tag_deleted      ENUM('false', 'true') NOT NULL,
	last_update      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	                 	ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (id)
);

CREATE TABLE flac_file
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	audio_file       MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES audio_file(id),
	flacstream_id    MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES flac_stream(id),
	PRIMARY KEY (id)
);

CREATE TABLE tag
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             VARCHAR(256) NOT NULL,
	text             VARCHAR(256) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE flac_stream
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	min_blocksize    MEDIUMINT UNSIGNED NOT NULL,
	max_blocksize    MEDIUMINT UNSIGNED NOT NULL,
	min_framesize    MEDIUMINT UNSIGNED NOT NULL,
	max_framesize    MEDIUMINT UNSIGNED NOT NULL,
	sample_rate      MEDIUMINT UNSIGNED NOT NULL,
	channels         TINYINT UNSIGNED NOT NULL,
	bits_per_sample  TINYINT UNSIGNED NOT NULL,
	total_samples    INT UNSIGNED NOT NULL,
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

# ==== MUSICBRAINZ =====================================================

CREATE TABLE artist
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	gid              CHAR(36) NOT NULL,
	name             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_name(id),
	sort_name        MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_name(id),
	PRIMARY KEY (id)
);

CREATE TABLE artist_name
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             VARCHAR(256) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE artist_credit
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_name(id),
	artist_count     TINYINT UNSIGNED NOT NULL,
	ref_count        SMALLINT UNSIGNED NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE artist_credit_name
(
	artist_credit    MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_credit(id), # PK
	position         TINYINT UNSIGNED NOT NULL,           # PK
	artist           MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist(id),
	name             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_name(id)
);

CREATE TABLE recording
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	gid              CHAR(36) NOT NULL,
	name             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES track_name(id),
	artist_credit    MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_credit(id),
	PRIMARY KEY (id)
);

CREATE TABLE tracklist
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	track_count      MEDIUMINT UNSIGNED NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE track
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	recording        MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES recording(id),
	tracklist        MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES tracklist(id),
	position         SMALLINT UNSIGNED NOT NULL,
	name             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES track_name(id),
	artist_credit    MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_credit(id),
	PRIMARY KEY (id)
);

CREATE TABLE track_name
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             VARCHAR(256) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE `release`
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	gid              CHAR(36) NOT NULL,
	name             MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES release_name(id),
	artist_credit    MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES artist_credit(id),
	release_group    MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES release_group(id),
	country          SMALLINT UNSIGNED NOT NULL
	                 	REFERENCES country(id),
	date_year        SMALLINT UNSIGNED NOT NULL,
	date_month       TINYINT UNSIGNED NOT NULL,
	date_day         TINYINT UNSIGNED NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE release_name
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             VARCHAR(256) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE country
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             VARCHAR(256) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE medium
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	tracklist        MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES tracklist(id),
	`release`          MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES `release`(id),
	position         SMALLINT UNSIGNED NOT NULL,
	format           MEDIUMINT UNSIGNED NOT NULL
	                 	REFERENCES medium_format(id),
	name             VARCHAR(256) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE medium_format
(
	id               MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name             VARCHAR(32) NOT NULL,
	PRIMARY KEY (id)
);
