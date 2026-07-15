import { existsSync } from "node:fs"
import { dirname, extname, resolve } from "node:path"

const generatedPath = /(?:^|\/)gen\/(?:go|typescript)(?:\/|$)/
const lintableExtensions = new Set([".ts", ".tsx", ".vue", ".js", ".mjs"])

function filePath(args) {
  return args.filePath ?? args.file_path ?? args.path
}

function absolutePath(path, worktree) {
  return resolve(worktree, path)
}

function protectedFile(path) {
  if (generatedPath.test(path)) {
    return "is proto-generated. Edit the .proto source and run 'make generate' instead."
  }

  if (path.endsWith(".enc.yaml")) {
    return "is a SOPS-encrypted secret. Use 'make secrets-edit' instead of editing directly."
  }
}

function eslintRoot(path, worktree) {
  let directory = dirname(path)

  while (directory.startsWith(worktree)) {
    if (existsSync(resolve(directory, "eslint.config.mjs"))) return directory
    if (directory === worktree) break
    directory = dirname(directory)
  }
}

export const WorkspaceGuards = async ({ $, worktree }) => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "edit" && input.tool !== "write") return

    const path = filePath(output.args)
    if (!path) return

    const absolute = absolutePath(path, worktree)
    const reason = protectedFile(absolute)
    if (reason) throw new Error(`Blocked: ${absolute} ${reason}`)
  },

  "tool.execute.after": async (input, output) => {
    if (input.tool !== "edit" && input.tool !== "write") return

    const path = filePath(output.args)
    if (!path) return

    const absolute = absolutePath(path, worktree)
    if (!existsSync(absolute)) return
    const extension = extname(absolute)

    if (extension === ".go") {
      await $`gofmt -s -w ${absolute}`
      await $`command -v goimports >/dev/null 2>&1 && goimports -w ${absolute}`.quiet()
      return
    }

    if (!lintableExtensions.has(extension)) return

    const root = eslintRoot(absolute, worktree)
    if (!root || !existsSync(resolve(root, "node_modules/.bin/eslint"))) return

    await $`./node_modules/.bin/eslint --fix ${absolute}`.cwd(root)
  },
})
