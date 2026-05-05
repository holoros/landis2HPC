// Contributors:
//   James Domingo, Forest Landscape Ecology Lab, UW-Madison

using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace Landis.Utilities.PlugIns
{
    /// <summary>
    /// Methods for loading plug-ins.
    /// </summary>
    public static class Loader
    {
        /// <summary>
        /// Loads a plug-in.
        /// </summary>
        /// <param name="T">
        /// The plug-in's interface.
        /// </param>
        /// <param name="info">
        /// Information about the plug-in to be loaded.
        /// </param>
        public static T Load<T>(IInfo info)
        {
            System.Type plugInImplType;
            try {
                // Patched: was System.Type.GetType(info.ImplementationName).
                // dotnet/runtime issue #103222: in .NET 8, Type.GetType() does not
                // discover types in assemblies loaded into custom AssemblyLoadContexts,
                // and .NET 8 also ignores the privatePath probing entries that
                // Landis.Console.dll.config uses to locate the extensions/ folder. We
                // fall back to walking the AppDomain, asking the default load context,
                // and finally probing the LANDIS extensions directory explicitly so the
                // type lookup goes through assembly.GetType(typeName) on the loaded
                // Assembly instance instead of the global Type.GetType cache.
                plugInImplType = ResolvePlugInType(info.ImplementationName);
            }
            catch (System.Exception exc) {
                if (string.IsNullOrEmpty(info.ImplementationName))
                    throw LoadException(info,
                                        "The plug-in has no implementation associated with it.");
                throw LoadException(info,
                                    "Cannot get the data type that implements the plug-in:",
                                    "  Data type:  " + info.ImplementationName,
                                    "  Error:      " + exc.Message);
            }
            if (plugInImplType == null)
                throw LoadException(info,
                                    "Cannot get the data type that implements the plug-in:",
                                    "  Data type:  " + info.ImplementationName,
                                    "  Error:      No data type with that name is installed.");

            return Load<T>(info.Name, plugInImplType);
        }

        //---------------------------------------------------------------------

        /// <summary>
        /// Loads a plug-in.
        /// </summary>
        /// <param name="T">
        /// The plug-in's interface.
        /// </param>
        /// <param name="name">
        /// The plug-in's name.
        /// </param>
        /// <param name="implementationType">
        /// The class that implements the plug-in.
        /// </param>
        public static T Load<T>(string      name,
                                System.Type implementationType)
        {
            string[] errMesg;
            try {
                System.Reflection.Assembly assembly = implementationType.Assembly;
                T plugIn = (T) assembly.CreateInstance(implementationType.FullName);
                if (plugIn != null)
                    return plugIn;
                errMesg = new string[]{"Could not create an instance of the plug-in."};
            }
            catch (System.InvalidCastException) {
                errMesg = new string[]{"The plug-in does not support the proper interface: " + typeof(T).FullName};
            }
            catch (System.Exception exc) {
                errMesg = new string[]{"Could not create an instance of the plug-in:",
                                       "  " + exc.Message};
            }
            throw LoadException(new Info(name, typeof(T), implementationType.AssemblyQualifiedName),
                                errMesg);
        }

        //---------------------------------------------------------------------

        private static Exception LoadException(IInfo           plugIn,
                                               params string[] messageLines)
        {
            return LoadException(plugIn, new MultiLineText(messageLines));
        }

        //---------------------------------------------------------------------

        private static Exception LoadException(IInfo         plugIn,
                                               MultiLineText message)
        {
            return new Exception(plugIn, "Error while loading the plug-in",
                                 message);
        }

        //---------------------------------------------------------------------

        /// <summary>
        /// Resolves a plug-in's implementation type from its
        /// AssemblyQualifiedName ("Namespace.TypeName, AssemblyName").
        /// </summary>
        /// <remarks>
        /// Workaround for dotnet/runtime issue #103222 and the loss of
        /// privatePath probing in .NET 8. The original implementation called
        /// System.Type.GetType(qualifiedName), which silently returns null when
        /// the extension assembly was loaded by a non-default
        /// AssemblyLoadContext or has not been probed yet because .NET 8
        /// ignores Landis.Console.dll.config's &lt;probing
        /// privatePath="8.0;extensions"/&gt;. Here we (1) try the original
        /// lookup, (2) walk already-loaded assemblies and call
        /// assembly.GetType(typeName), (3) ask the default load context via
        /// Assembly.Load(AssemblyName), and (4) probe canonical LANDIS-II
        /// extension directories on disk before giving up. Returns null if all
        /// strategies fail; the caller already handles that case.
        /// </remarks>
        private static System.Type ResolvePlugInType(string assemblyQualifiedName)
        {
            if (string.IsNullOrEmpty(assemblyQualifiedName))
                return null;

            // 1. Original behaviour. Cheap and correct in legacy contexts.
            System.Type type = System.Type.GetType(assemblyQualifiedName);
            if (type != null)
                return type;

            // Parse "TypeName, AssemblyName[, Version=..., Culture=..., PublicKeyToken=...]".
            int comma = assemblyQualifiedName.IndexOf(',');
            if (comma < 0)
                return null;
            string typeName = assemblyQualifiedName.Substring(0, comma).Trim();
            string assemblyTail = assemblyQualifiedName.Substring(comma + 1).Trim();
            int firstSeparator = assemblyTail.IndexOf(',');
            string assemblyName = firstSeparator < 0
                ? assemblyTail
                : assemblyTail.Substring(0, firstSeparator).Trim();
            if (string.IsNullOrEmpty(typeName) || string.IsNullOrEmpty(assemblyName))
                return null;

            // 2. Walk every assembly already loaded in the AppDomain. This is the
            //    documented workaround in dotnet/runtime#103222 for
            //    AssemblyLoadContext-loaded extensions.
            foreach (System.Reflection.Assembly loaded in
                     System.AppDomain.CurrentDomain.GetAssemblies())
            {
                AssemblyName loadedName;
                try { loadedName = loaded.GetName(); }
                catch (System.Exception) { continue; }

                if (string.Equals(loadedName.Name, assemblyName,
                                  System.StringComparison.OrdinalIgnoreCase))
                {
                    System.Type t = loaded.GetType(typeName);
                    if (t != null)
                        return t;
                }
            }

            // 3. Try to load through the default load context. If the runtime can
            //    locate the assembly via deps.json or AppContext probing, this is
            //    enough.
            try
            {
                System.Reflection.Assembly asm = System.Reflection.Assembly.Load(
                    new AssemblyName(assemblyName));
                if (asm != null)
                {
                    System.Type t = asm.GetType(typeName);
                    if (t != null)
                        return t;
                }
            }
            catch (System.Exception)
            {
                // Continue to explicit file probing.
            }

            // 4. Explicit file probing of canonical LANDIS-II layouts. The
            //    Console binary lives at .../build/Release/Landis.Console.dll
            //    and extension DLLs at .../build/extensions/*.dll, mirroring the
            //    privatePath="8.0;extensions" entry in Landis.Console.dll.config.
            string baseDir = System.AppContext.BaseDirectory;
            string[] candidates = new string[]
            {
                Path.Combine(baseDir, assemblyName + ".dll"),
                Path.Combine(baseDir, "extensions", assemblyName + ".dll"),
                Path.Combine(baseDir, "..", "extensions", assemblyName + ".dll"),
                Path.Combine(baseDir, "8.0", assemblyName + ".dll"),
                Path.Combine(baseDir, "..", "8.0", assemblyName + ".dll"),
            };
            foreach (string candidate in candidates)
            {
                try
                {
                    if (!File.Exists(candidate))
                        continue;
                    System.Reflection.Assembly asm =
                        System.Reflection.Assembly.LoadFrom(candidate);
                    System.Type t = asm.GetType(typeName);
                    if (t != null)
                        return t;
                }
                catch (System.Exception)
                {
                    // Try the next candidate.
                }
            }

            return null;
        }
    }
}
