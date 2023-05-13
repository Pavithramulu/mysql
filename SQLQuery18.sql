
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE 
    @TableA nvarchar(255)='TableA',
    @DOCID1 nvarchar(MAX),
    @SqlStmt NVARCHAR(500),
    @DOCID2 int;

SET @SqlStmt = N'SELECT TOP (1) ' + @DOCID1 + N' = DOCID1, ' + @DOCID2 + N' = DOCID2 FROM [' + @TABLEA + N'] ORDER BY DOCID2';

EXEC (@SqlStmt)

CREATE PROCEDURE OTTStoreProcedure
           (@OTTAction varchar(100)=null,
		    @Category_ID int = 0,
		    @Movie varchar(100)=null,
			@Serial varchar(100)=null,
			@Sports varchar(100)=null,
			@[User_ID] int = 0,
			@[User_Name] varchar(100)=null,
			@Gender varchar(100)=null,
			@Mobile_Number varchar(100)=null,
			@[Address] varchar(100)=null,
			@Video_ID int =0,
			@Category_ID int = 0,
			@Title varchar(200)=null,
			@[Description] nvarchar(4000)=null,
			@ImageURL nvarchar(4000)=null,
			@VideoURL nvarchar(4000)=null,
			@Release_Date datetime
		   )

AS @OTTAction = 'OTTInsertAuction'
BEGIN

INSERT INTO [dbo].[OTTStoreProcedure]
           ([OTTAction] 
		    [Category_ID]
		    [Movie]
			[Serial] 
			[Sports]
			[User_ID] 
			[User_Name] 
			[Gender] 
			[Mobile_Number] 
			[Address]
			[Video_ID] 
			[Category_ID] 
			[Title] 
			[Description] 
			[ImageURL] 
			[VideoURL] 
			[Release_Date]
		   )

		   VALUES

		   (@OTTAction, 
		    @Category_ID,
		    @Movie,
			@Serial,
			@Sports,
			@[User_ID],
			@[User_Name],
			@Gender,
			@Mobile_Number,
			@[Address],
			@Video_ID,
			@Category_ID,
			@Title,
			@[Description],
			@ImageURL,
			@VideoURL,
			@Release_Date
		   )
		   
		   Select '1'
END








