param()

$ErrorActionPreference = "Stop"

# Pfad zur Valheim DLL auf GitHub Actions VM
$DllPath = "C:\vtemp\valheim_ds\valheim_server_Data\Managed\assembly_valheim.dll"
$OutputDll = "assembly_valheim.dll"

# Mono.Cecil laden (wurde im Workflow heruntergeladen)
$CecilDll = Get-ChildItem -Path "C:\vtemp\cecil\lib" -Recurse -Filter "Mono.Cecil.dll" | Select-Object -First 1
if (-not $CecilDll) { throw "Mono.Cecil.dll nicht gefunden" }
$MonoCecilPath = $CecilDll.FullName

Add-Type -ReferencedAssemblies @("System.Core", $MonoCecilPath) -TypeDefinition @"
using System;
using System.Linq;
using Mono.Cecil;
using Mono.Cecil.Cil;

public static class ValheimPatcher
{
    public static void Patch(string path)
    {
        var asm = AssemblyDefinition.ReadAssembly(path);
        var module = asm.MainModule;

        var zdoType = module.Types.FirstOrDefault(t => t.Name == "ZDOMan");
        if (zdoType == null) throw new Exception("Typ 'ZDOMan' nicht gefunden.");

        var method = zdoType.Methods.FirstOrDefault(m => m.Name == "SendZDOs");
        if (method == null) throw new Exception("Methode 'SendZDOs' nicht gefunden.");

        int patched = 0;
        foreach (var instr in method.Body.Instructions)
        {
            if (instr.OpCode == OpCodes.Ldc_I4 && instr.Operand is int v && v == 10240)
            {
                instr.Operand = 30720;
                patched++;
            }
        }

        if (patched != 2)
            throw new Exception("Erwartet: 2 Konstanten 10240, tatsächlich gepatcht: " + patched);

        asm.Write(path);
    }
}
"@

Write-Host "==> Patche assembly_valheim.dll..."
[ValheimPatcher]::Patch($DllPath)

# Kopiere die gepatchte DLL ins Repo-Arbeitsverzeichnis für Upload
Copy-Item $DllPath $OutputDll -Force
Write-Host "==> Fertig. DLL bereit zum Upload: $OutputDll"