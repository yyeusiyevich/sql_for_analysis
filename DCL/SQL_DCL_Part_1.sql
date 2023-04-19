-- 1. Figure out what security precautions are already used in your 'dvd_rental' database; -- send description
--list of roles
SELECT rolname FROM pg_roles;

/* There are predefined roles that come with the system. They include:
pg_signal_backend: allows a user to signal other backend processes, such as killing a long-running query;
pg_read_all_settings: allows a user to read all of the configuration settings in the postgresql.conf file;
pg_read_all_stats: allows a user to access the statistics collected by the system;
pg_monitor: allows a user to monitor the system and its performance;
pg_checkpoint: this role has the ability to initiate checkpoint operations, which flush the contents of shared memory to disk;
pg_database_owner: this role is the owner of a database and has complete control over it;
pg_execute_server_program: allows to execute server programs, such as procedural languages and extensions;
pg_read_all_data: this role has the ability to read all data from all databases;
pg_read_server_files: this role has the ability to read all files on the server's file system that are readable by the PostgreSQL server;
pg_stat_scan_tables: allows to run queries that perform table scans and return statistical information;
pg_write_all_data: allows to write to all data in all databases;
pg_write_server_files: allows to write to all files on the server's file system that are writable by the PostgreSQL server.
*/

/* A freshly initialized system always contains one more predefined role - here it is postgres role. 
 * This role is always a "superuser", and by default (unless altered when running initdb) it will have the same name as the operating system user that initialized the database cluster. 
 */
