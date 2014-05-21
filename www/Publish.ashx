<%@ WebHandler Language="C#" Class="Publish" %>

using System;
using System.Web;
using System.Collections.Generic;
using System.Net;
using System.Linq;
using System.IO;

using ICSharpCode.SharpZipLib.Zip;

public class Publish : IHttpHandler
{

    public bool IsReusable
    {
        get
        {
            return false;
        }
    }

    public void ProcessRequest(HttpContext context)
    {
        var Context = HttpContext.Current;
        var Server = HttpContext.Current.Server;

        Context.Response.ContentType = "text/plain";

        var list = GetPublishList();
        foreach (var p in list)
        {
            var zipUrl = p.GitHubUrl;

            var zipFilePath = Server.MapPath("~/Temp/Zip/" + "temp.zip");
            var zipFile = new FileInfo(zipFilePath);
            var unzipDirPath = Server.MapPath("~/Temp/Unzip/" + "temp/");
            var unzipDir = new DirectoryInfo(unzipDirPath);

            // Load Zip
            Context.Response.Write("Loading Zip\r\n");
            Context.Response.Flush();
            //GetGithubZipFile(zipUrl, zipFile);
            Context.Response.Write("\r\nDownloaded Zip\r\n");
            Context.Response.Flush();

            // Unzip
            UnzipFile(zipFile, unzipDir);
            Context.Response.Write("\r\nUnzipped\r\n");

            // Copy to dest path
            var repoDirName = Directory.GetDirectories(unzipDirPath)[0].TrimEnd('\\');
            var sourceDirPath = repoDirName + "\\www\\";
            var destDirPath = Server.MapPath("~/" + p.DestinationRelativePath + "/");
            
            
            var filesToMove = Directory.GetFiles(sourceDirPath, "*.*", SearchOption.AllDirectories);

            foreach (var f in filesToMove)
            {
                var relPath = f.Substring(sourceDirPath.Length);
                var fDest = destDirPath + relPath;
                var fInfoDest = new FileInfo(fDest);

                if (!fInfoDest.Directory.Exists)
                {
                    fInfoDest.Directory.Create();
                }

                File.Copy(f, fDest, true);
            }

            Context.Response.Write("\r\nDeployed\r\n");
        }

    }

    private List<PublishEntry> GetPublishList()
    {
        var Context = HttpContext.Current;
        var Server = HttpContext.Current.Server;

        var listFilePath = Server.MapPath("~/Git2SiteList.txt");
        var listFile = new FileInfo(listFilePath);

        if (!listFile.Exists)
        {
            Context.Response.Write("Git2SiteList.txt is missing");
            Context.Response.End();
        }

        var t = File.ReadAllText(listFile.FullName);

        var entries = from l in t
                      .Replace("\t", " ")
                          .Replace("    ", " ")
                          .Replace("   ", " ")
                          .Replace("  ", " ")
                          .Replace("  ", " ")
                          .Split('\n')
                      let line = l.Trim()
                      where !line.StartsWith("//")
                      let parts = line.Split()
                      where parts.Length == 2
                      let url = new Uri(parts[0].Trim())
                      let path = parts[1].Trim(new char[] { '\\', ' ' })
                      select new PublishEntry() { GitHubUrl = url, DestinationRelativePath = path };

        return entries.ToList();
    }

    private void UnzipFile(FileInfo zipFile, DirectoryInfo unzipDir)
    {
        var Context = HttpContext.Current;
        var Server = HttpContext.Current.Server;

        if (!unzipDir.Exists)
        {
            unzipDir.Create();
        }

        using (var fStream = new FileStream(zipFile.FullName, FileMode.Open))
        using (var s = new ZipInputStream(fStream))
        {
            // From http://jes.al/2008/03/how-to-unzip-files-in-net-using-sharpziplib/
            ZipEntry theEntry;
            string rootDir = unzipDir.FullName;
            string fileName = string.Empty;
            string fileExtension = string.Empty;
            string fileDir = string.Empty;

            while ((theEntry = s.GetNextEntry()) != null)
            {
                fileName = Path.GetFileName(theEntry.Name);
                fileExtension = Path.GetExtension(fileName);

                fileDir = Path.GetDirectoryName(theEntry.Name) + "\\";

                if (!string.IsNullOrEmpty(fileName))
                {
                    try
                    {
                        var zFile = new FileInfo(rootDir + fileDir + fileName);
                        if (!zFile.Directory.Exists)
                        {
                            zFile.Directory.Create();
                        }

                        using (FileStream streamWriter = File.Create(zFile.FullName))
                        {
                            int size = 2048;
                            byte[] data = new byte[2048];

                            do
                            {
                                size = s.Read(data, 0, data.Length);
                                streamWriter.Write(data, 0, size);
                            } while (size > 0);

                        }

                    }
                    catch (Exception ex)
                    {
                        Context.Response.Write(ex.ToString());
                        Context.Response.End();
                    }
                }
            }

        }

        return;
    }

    private void GetGithubZipFile(Uri githubRepoUrl, FileInfo zipFile)
    {
        var Context = HttpContext.Current;
        var Server = HttpContext.Current.Server;


        if (!zipFile.Directory.Exists)
        {
            zipFile.Directory.Create();
        }

        //var data = new List<byte>();
        var request = HttpWebRequest.Create(githubRepoUrl);

        using (var response = request.GetResponse())
        using (var rStream = response.GetResponseStream())
        using (var fStream = new FileStream(zipFile.FullName, FileMode.Create))
        {

            var size = 10240;
            var buffer = new byte[size];
            var bytesRead = rStream.Read(buffer, 0, size);

            while (bytesRead > 0)
            {
                //data.AddRange(buffer.Take(bytesRead));
                fStream.Write(buffer, 0, bytesRead);
                bytesRead = rStream.Read(buffer, 0, size);

                Context.Response.Write(".");
            }

        }

    }


    class PublishEntry
    {
        public Uri GitHubUrl { get; set; }
        public string DestinationRelativePath { get; set; }
    }
}