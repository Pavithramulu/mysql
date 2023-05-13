
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE VideoDetailsSP 
          @OTTAction varchar(100)=null,
		    @Category_ID int = 0,
		    @Movie varchar(100)=null,
			@Serial varchar(100)=null,
			@Sports varchar(100)=null,
			@UserID int = 0,
			@UserName varchar(100)=null,
			@Gender varchar(100)=null,
			@Mobile_Number varchar(100)=null,
			@Address varchar(100)=null,
			@Video_ID int =0,
			@Title varchar(200)=null,
			@Description nvarchar(4000)=null,
			@ImageURL nvarchar(4000)=null,
			@VideoURL nvarchar(4000)=null,
			@Release_Date datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	
	SET NOCOUNT ON;

     IF(@OTTAction = 'OTTInsertAuction')
	 BEGIN

		INSERT INTO [dbo].[OTTStoreProcedure]
				   ([OTTAction] ,
					[Category_ID],
					[Movie],
					[Serial] ,
					[Sports],
					[User_ID] ,
					[User_Name] ,
					[Gender], 
					[Mobile_Number] ,
					[Address],
					[Video_ID], 
					[Category_ID] ,
					[Title] ,
					[Description] ,
					[ImageURL] ,
					[VideoURL] ,
					[Release_Date]
				   )

				   VALUES

				   (@OTTAction, 
					@Category_ID,
					@Movie,
					@Serial,
					@Sports,
					@UserID,
					@UserName,
					@Gender,
					@Mobile_Number,
					@Address,
					@Video_ID,
					@Category_ID,
					@Title,
					@Description,
					@ImageURL,
					@VideoURL,
					@Release_Date
				   )
		   
				   Select '1'
	END
	 ELSE IF(@OTTAction = 'Get')
	 BEGIN
		 

	 END

END
GO
