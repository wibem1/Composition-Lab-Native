namespace CompositionLab;

internal static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        var test = args.Contains("--self-test");
        var output = args.SkipWhile(a => a != "--test-output").Skip(1).FirstOrDefault();
        Application.ThreadException += (_, e) => MessageBox.Show(e.Exception.Message, "Composition Lab 4.2");
        using var form = new MainForm(test);
        if (test)
        {
            form.Shown += async (_, _) =>
            {
                try
                {
                    var report = await form.RunSelfTestAsync(output ?? "self-test");
                    Directory.CreateDirectory(output ?? "self-test");
                    File.WriteAllText(Path.Combine(output ?? "self-test", "result.json"), report);
                    Environment.ExitCode = 0;
                }
                catch (Exception e)
                {
                    Directory.CreateDirectory(output ?? "self-test");
                    File.WriteAllText(Path.Combine(output ?? "self-test", "failure.txt"), e.ToString());
                    Environment.ExitCode = 1;
                }
                form.Close();
            };
        }
        Application.Run(form);
    }
}
