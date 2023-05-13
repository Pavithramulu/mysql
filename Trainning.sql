USE Training

INSERT INTO [User] (FirstName,Age,Gender,email) VALUES ('ccc',44,'F')
INSERT INTO [User] (FirstName,Age,Gender,email) VALUES ('fgfg',44,'F')
INSERT INTO [User] (FirstName,Age,Gender,email) VALUES ('ghghg',44,'F')
INSERT INTO [User] (FirstName,Age,Gender,email) VALUES ('sere',44,'F')


SELECT distinct firstname,age FROM [User]

select  * from [User] where NOT age = 44



INSERT INTO [User] (FirstName,Age,Gender) VALUES ('XXX',44,'F')
INSERT INTO [User] (FirstName,Age,Gender) VALUES ('XXX',44,'F')
INSERT INTO [User] (FirstName,Age,Gender) VALUES ('YYY',44,'F')

INSERT INTO [User] (FirstName,Age,Gender) VALUES ('XXX',54,'F')