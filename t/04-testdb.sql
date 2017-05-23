-- MySQL dump 10.15  Distrib 10.0.28-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: 10.0.3.200    Database: 10.0.3.200
-- ------------------------------------------------------
-- Server version       10.0.28-MariaDB-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `borrowers`
--

DROP TABLE IF EXISTS `borrowers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `borrowers` (
  `borrowernumber` int(11) NOT NULL AUTO_INCREMENT,
  `cardnumber` varchar(16) COLLATE utf8_unicode_ci DEFAULT NULL,
  `surname` mediumtext COLLATE utf8_unicode_ci NOT NULL,
  `firstname` text COLLATE utf8_unicode_ci,
  `title` mediumtext COLLATE utf8_unicode_ci,
  `othernames` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `address` mediumtext COLLATE utf8_unicode_ci NOT NULL,
  `email` mediumtext COLLATE utf8_unicode_ci,
  `phone` text COLLATE utf8_unicode_ci,
  `dateofbirth` date DEFAULT NULL,
  `branchcode` varchar(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT '',
  `password` varchar(60) COLLATE utf8_unicode_ci DEFAULT NULL,
  `userid` varchar(75) COLLATE utf8_unicode_ci DEFAULT NULL,
  `opacnote` mediumtext COLLATE utf8_unicode_ci,
  PRIMARY KEY (`borrowernumber`),
  UNIQUE KEY `cardnumber` (`cardnumber`),
  UNIQUE KEY `othernames` (`othernames`),
  UNIQUE KEY `userid` (`userid`),
  KEY `branchcode` (`branchcode`),
  KEY `surname_idx` (`surname`(255)),
  KEY `firstname_idx` (`firstname`(255)),
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `borrowers`
--

LOCK TABLES `borrowers` WRITE;
/*!40000 ALTER TABLE `borrowers` DISABLE KEYS */;
INSERT INTO `borrowers` VALUES (1,"23529000445172","Daniels","Tanya","Mrs","respok",    "2035 Library Rd.", NULL,                   "(212) 555-1212","1966-10-14","MPL","42b29d0771f3b7ef","23529000445172",NULL),(2,"23529000105040","Dillon", "Eva",  "Ms", "Nightrider","8916 Library Rd.","harrier@example.com","(212) 555-1212","1952-04-03","MPL","42b29d0771f3b7ef","23529000105040","This is a note");
/*!40000 ALTER TABLE `borrowers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_queue`
--

DROP TABLE IF EXISTS `message_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `message_queue` (
  `message_id` int(11) NOT NULL AUTO_INCREMENT,
  `content` text COLLATE utf8_unicode_ci,
  `to_address` mediumtext COLLATE utf8_unicode_ci,
  PRIMARY KEY (`message_id`),
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_queue`
--

LOCK TABLES `message_queue` WRITE;
/*!40000 ALTER TABLE `message_queue` DISABLE KEYS */;
INSERT INTO `message_queue` VALUES (1,"This is a test content\nThis is lke any other text\n    sometimes padded and centralized   \n","email55@example55.com"),(2,"Another test message","hopeful@together.com");
/*!40000 ALTER TABLE `message_queue` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `binaryblob`
--

DROP TABLE IF EXISTS `binaryblob`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `binaryblob` (
  `bin_id` int(11) NOT NULL AUTO_INCREMENT,
  `description` text COLLATE utf8_unicode_ci,
  `biblob` blob,
  PRIMARY KEY (`binaryblob`),
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `binaryblob`
--

LOCK TABLES `binaryblob` WRITE;
/*!40000 ALTER TABLE `binaryblob` DISABLE KEYS */;
INSERT INTO `binaryblob` VALUES (1,'Binary data mess','x89PNG\n\\n\0\0\0\nIHDR\0\0\0x8C\0\0\0xC9\0\0\0~7MxB6\0\0 \0IDATxx9C4xBBxD9xCE-Yx92xAD5xCClxCExE9xEExABxFDx9BxDDDx93xD9Tex9CxAARx9DxBAxE0x80@xB8Fx82$.x8Ex84G\\xF2<x80\0QTQx8D*+xA32xA3xD9xB1x9BxBF]ky7xA75\\xECxC2`xCAxE5Sf6|x8CxCF蛿xFD_xCBfB]xBBx9CxE6xAEDf11zxC7y}xFAn}xB1xD9ݼ|AxF23x84AxC4xA5(@H\\nxA8xF3xE6M@\	Lā\0@HxFFxFFC\0xxE2xA1xA1xA7xB0xECPv}2x9B$2xA5-xA5x88xE1x98Cg&fxF3Z<*Ñn@xACުxA3xE1x94xCCxF8iY>x9CxEEOxA7uVDxAFxAExBExxF5xF9x90zPsx840x8BTx95\0\\nx88x907+x80xD');
/*!40000 ALTER TABLE `binaryblob` ENABLE KEYS */;
UNLOCK TABLES;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-04-27 17:38:50