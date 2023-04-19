-- How can one restrict access to certain columns of a database table?
/* To restrict access to certain columns of a database table, one can use column-level privileges. 
 * In PostgreSQL, one can grant and revoke privileges on specific columns using DCL commands like GRANT and REVOKE. 
 * For example, to grant SELECT privileges on the "first_name" and "last_name" columns of the "customer" table to the "readonly" role, 
 * one would run the following commands: */
-- GRANT SELECT (first_name, last_name) ON customer TO readonly;
/* Another way is to use views. One can create a view that selects only the columns to expose, 
 * and grant privileges on the view to a role. Following the previous example: */
-- CREATE VIEW customer_name_view AS SELECT first_name, last_name FROM customer; 
-- GRANT SELECT ON customer_name_view TO readonly;

-- What is the difference between user identification and user authentication?
/* User identification and user authentication are related concepts in security, but they refer to different aspects of the process of verifying the identity of a user.
User identification refers to the process of identifying who a user is, typically by asking for a unique identifier such as a username or email address.
User authentication, on the other hand, refers to the process of verifying that the user is indeed who they claim to be, typically through the use of a password or other authentication mechanism.
So, user identification is the first step in the process of verifying a user's identity, while user authentication is the step of verifying that identity through some form of validation.*/
 
-- What are the recommended authentication protocols for PostgreSQL?
/* PostgreSQL supports several authentication protocols for verifying the identity of users trying to access a database. 
Password authentication: the most common and simple authentication protocol, where the user provides a username and password to log in to the database.
md5 authentication: a more secure version of password authentication, where the password is hashed using the md5 algorithm before being stored in the database.
peer authentication: uses the client operating system's user names and authentication mechanism to determine if the user is authorized to access the database. 
This method is recommended for use on local networks where all clients and servers are trusted.
GSSAPI (Kerberos) authentication: uses the Kerberos network authentication protocol to verify the identity of the user. 
This method is recommended for use in enterprise environments where a centralized authentication server is available.
PAM (Pluggable Authentication Modules) authentication: uses the PAM framework to verify the identity of the user. 
This method allows for integration with a variety of authentication systems.
The recommended authentication protocol for a particular use case will depend on various factors such as the level of security required, the network environment, and the authentication mechanisms already in place.
 */

-- What is proxy authentication in PostgreSQL and what is it for? Why does it make the previously discussed role-based access control easier to
-- implement?
/* Proxy authentication in PostgreSQL is a mechanism for allowing one user to access the database with the privileges of another user. In other words, a user can connect to the database as themselves, but then act as if they were another user. 
This is useful in scenarios where a user needs to perform actions on behalf of another user, but doesn't have the necessary privileges to do so directly.
The trusted user can then perform actions on behalf of the limited-privilege user, such as creating tables or modifying data, without having to be granted those privileges directly.
To implement proxy authentication in PostgreSQL, the DBA must create a user for the proxy and assign it the necessary privileges. 
Then, the proxy user must be granted the "PROXY" privilege for the target user. The proxy user can then connect to the database and specify the target user with the "SET ROLE" command.
The proxy user should be carefully chosen and trusted, and the privileges granted to the proxy user should be limited to only what is necessary to perform its intended tasks.
Proxy authentication can make role-based access control easier to implement because it allows for a separation of duties and delegation of responsibilities. 
With proxy authentication, a user with high privileges can delegate the execution of specific tasks to a user with limited privileges, without having to grant those privileges directly to the limited-privilege user.
For example, consider a scenario where a database administrator needs to perform routine maintenance on the database, but doesn't want to log in as the superuser or grant the maintenance user any more privileges than necessary. 
In this case, the database administrator can connect to the database as the maintenance user, but then execute the necessary commands with their own privileges. 
This allows for a more secure and controlled environment, as the maintenance user is limited to only the privileges they need to perform their intended tasks.*/