using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

internal static class Program
{
    private static string _root;
    private static int _port;

    private static void Main(string[] args)
    {
        _root = AppDomain.CurrentDomain.BaseDirectory;
        _port = 8080;
        if (args.Length > 0) int.TryParse(args[0], out _port);
        if (_port <= 0) _port = 8080;

        var listener = new TcpListener(IPAddress.Loopback, _port);
        try
        {
            listener.Start();
        }
        catch (Exception ex)
        {
            Console.WriteLine("Cannot start server on port " + _port + ": " + ex.Message);
            Console.WriteLine("If the game is already open, just refresh the browser.");
            Console.ReadKey();
            return;
        }

        Console.WriteLine("NaiwaForest Web Server");
        Console.WriteLine("http://127.0.0.1:" + _port + "/index.html");
        Console.WriteLine("Keep this window open. Press Ctrl+C to stop.");

        while (true)
        {
            var client = listener.AcceptTcpClient();
            Task.Run(() => Handle(client));
        }
    }

    private static void Handle(TcpClient client)
    {
        try
        {
            using (client)
            using (var stream = client.GetStream())
            {
                var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, true);
                var first = reader.ReadLine();
                if (string.IsNullOrEmpty(first)) return;
                var parts = first.Split(' ');
                if (parts.Length < 2) return;
                var path = parts[1];
                var q = path.IndexOf('?');
                if (q >= 0) path = path.Substring(0, q);
                path = Uri.UnescapeDataString(path);
                if (path == "/") path = "/index.html";
                var relative = path.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                var full = Path.GetFullPath(Path.Combine(_root, relative));
                if (!full.StartsWith(Path.GetFullPath(_root), StringComparison.OrdinalIgnoreCase) || !File.Exists(full))
                {
                    WriteHead(stream, 404, "text/plain", 0);
                    var notFound = Encoding.UTF8.GetBytes("Not Found");
                    stream.Write(notFound, 0, notFound.Length);
                    return;
                }

                var data = File.ReadAllBytes(full);
                var mime = Mime(Path.GetExtension(full).ToLowerInvariant());
                WriteHead(stream, 200, mime, data.Length);
                stream.Write(data, 0, data.Length);
            }
        }
        catch
        {
            // Browser may close a connection while assets are loading.
        }
    }

    private static void WriteHead(NetworkStream stream, int code, string mime, int length)
    {
        var sb = new StringBuilder();
        sb.Append("HTTP/1.1 ").Append(code).Append(code == 200 ? " OK" : " Not Found").Append("\r\n");
        sb.Append("Content-Type: ").Append(mime).Append("\r\n");
        sb.Append("Content-Length: ").Append(length).Append("\r\n");
        sb.Append("Cross-Origin-Opener-Policy: same-origin\r\n");
        sb.Append("Cross-Origin-Embedder-Policy: require-corp\r\n");
        sb.Append("Cross-Origin-Resource-Policy: cross-origin\r\n");
        sb.Append("Cache-Control: no-store\r\n");
        sb.Append("Connection: close\r\n\r\n");
        var head = Encoding.ASCII.GetBytes(sb.ToString());
        stream.Write(head, 0, head.Length);
    }

    private static string Mime(string ext)
    {
        switch (ext)
        {
            case ".html": return "text/html; charset=utf-8";
            case ".js": return "application/javascript; charset=utf-8";
            case ".wasm": return "application/wasm";
            case ".pck": return "application/octet-stream";
            case ".png": return "image/png";
            case ".css": return "text/css";
            case ".txt": return "text/plain; charset=utf-8";
            default: return "application/octet-stream";
        }
    }
}
