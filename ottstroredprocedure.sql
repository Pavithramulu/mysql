USE [_OTT]
GO
/****** Object:  StoredProcedure [dbo].[VideoDetailsSP]    Script Date: 13-05-2023 02:01:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[VideoDetailsSP] 
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
			@Release_Date datetime = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	
	SET NOCOUNT ON;

     IF(@OTTAction = 'OTTInsertAction')
	 BEGIN
				INSERT INTO OTTVideo (Category_ID,Title,Description,ImageURL,VideoURL,release_date)
				VALUES (@Category_ID,@Title,@Description,@ImageURL,@VideoURL,@Release_Date)

		   
				Select '1'
	END
	ELSE IF(@OTTAction = 'GetBannerImages')
	BEGIN

		SELECT TOP 5 Video_ID,Category_ID,ImageURL from OTTVideo order by Release_Date desc

	END
	ELSE IF(@OTTAction = 'GetMovieCategoryVideos')
	BEGIN

		SELECT TOP 5 Video_ID,Category_ID,ImageURL from OTTVideo where category_id = 1 order by Release_Date desc

	END
	ELSE IF(@OTTAction = 'GetSeriesCategoryVideos')
	BEGIN

		SELECT TOP 5 video_Id,Category_ID,ImageURL from OTTVideo where category_id = 2 order by Release_Date desc

	END

	ELSE IF(@OTTAction = 'GetSportsCategoryVideos')
	BEGIN

		SELECT TOP 5 video_Id,Category_ID,ImageURL from OTTVideo where category_id = 3 order by Release_Date desc

	END







END
