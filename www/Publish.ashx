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

        var zipUrl = "https://github.com/ricklove/CommonCoreMathProblems/archive/master.zip";

        var zipFilePath = Server.MapPath("~/Temp/Zip/" + "test.zip");
        var zipFile = new FileInfo(zipFilePath);
        var unzipDirPath = Server.MapPath("~/Temp/Unzip/" + "test/");
        var unzipDir = new DirectoryInfo(unzipDirPath);

        Context.Response.Write("Loading Zip\r\n");
        Context.Response.Flush();

        GetGithubZipFile(new Uri(zipUrl), zipFile);
        Context.Response.Write("\r\nDownloaded Zip\r\n");
        Context.Response.Flush();

        UnzipFile(zipFile, unzipDir);
        Context.Response.Write("\r\nUnzipped\r\n");
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



}