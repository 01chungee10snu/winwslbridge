// Minimal Windows bridge host skeleton for planning and early prototyping.
// Intentionally limited to health/capabilities style responses.
// Expand capabilities gradually and keep the host in the interactive user session.

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

public class BridgeRequest
{
    public string? action { get; set; }
    public Dictionary<string, object>? args { get; set; }
}

public class BridgeResponse
{
    public bool ok { get; set; }
    public string action { get; set; } = "";
    public object? result { get; set; }
    public string? error { get; set; }
    public long durationMs { get; set; }
}

public static class Program
{
    private static readonly Dictionary<string, object> Capabilities = new()
    {
        ["health"] = true,
        ["capabilities"] = true,
        ["window.list"] = false,
        ["screen.capture"] = false,
        ["window.focus"] = false,
        ["clipboard.getText"] = false,
        ["browser.openUrl"] = false,
    };

    public static async Task Main()
    {
        const string pipeName = "OpenClawBridge";
        while (true)
        {
            using var server = new NamedPipeServerStream(
                pipeName,
                PipeDirection.InOut,
                1,
                PipeTransmissionMode.Byte,
                PipeOptions.Asynchronous);

            await server.WaitForConnectionAsync();
            await HandleClient(server);
        }
    }

    private static async Task HandleClient(Stream stream)
    {
        var started = DateTimeOffset.UtcNow;
        try
        {
            using var reader = new StreamReader(stream, Encoding.UTF8, leaveOpen: true);
            using var writer = new StreamWriter(stream, new UTF8Encoding(false), leaveOpen: true) { AutoFlush = true };

            var line = await reader.ReadLineAsync();
            var req = JsonSerializer.Deserialize<BridgeRequest>(line ?? "{}") ?? new BridgeRequest();
            var resp = Dispatch(req, started);
            await writer.WriteLineAsync(JsonSerializer.Serialize(resp));
        }
        catch (Exception ex)
        {
            var resp = new BridgeResponse
            {
                ok = false,
                action = "error",
                error = ex.Message,
                durationMs = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
            };
            using var writer = new StreamWriter(stream, new UTF8Encoding(false), leaveOpen: true) { AutoFlush = true };
            await writer.WriteLineAsync(JsonSerializer.Serialize(resp));
        }
    }

    private static BridgeResponse Dispatch(BridgeRequest req, DateTimeOffset started)
    {
        return req.action switch
        {
            "health" => new BridgeResponse
            {
                ok = true,
                action = "health",
                result = new { status = "ok", session = "interactive-user" },
                durationMs = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
            },
            "capabilities" => new BridgeResponse
            {
                ok = true,
                action = "capabilities",
                result = Capabilities,
                durationMs = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
            },
            _ => new BridgeResponse
            {
                ok = false,
                action = req.action ?? "",
                error = "unsupported action",
                durationMs = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
            }
        };
    }
}
