---
name: security-validation
description: Systematic security analysis for code changes. Checks for OWASP top-10, secrets in code, dependency vulnerabilities, and injection risks.
---

# Security Validation Skill

This skill provides systematic security analysis for code changes before they are committed. It checks for common vulnerabilities, secrets exposure, injection risks, and unsafe patterns.

## When Claude Should Use This Skill

Claude will automatically invoke this skill when:
- Before `code-implementer` commits (post-implementation gate)
- During `brahma-analyzer` validation
- When code touches auth, crypto, user input, SQL, or external APIs
- User explicitly requests security review

## Core Principles

1. **Defense in depth** - Multiple layers of checks catch different vulnerability classes
2. **Shift left** - Find security issues before code reaches production
3. **Zero trust for user input** - All external input is untrusted
4. **Least privilege** - Code should request minimum necessary permissions
5. **Fail secure** - Errors should not expose sensitive information

## Security Check Categories

### Category 1: Secrets Detection (30 points)

**What to check**:
- API keys, tokens, passwords hardcoded in source
- `.env` file contents committed to version control
- Private keys, certificates, or credentials in code
- Connection strings with embedded passwords
- AWS/GCP/Azure credential patterns

**Common patterns to flag**:
```
# Dangerous patterns (regex)
(api[_-]?key|apikey)\s*[:=]\s*['"][A-Za-z0-9]{16,}
(password|passwd|pwd)\s*[:=]\s*['"][^'"]+['"]
(secret|token)\s*[:=]\s*['"][A-Za-z0-9]{16,}
(AKIA[0-9A-Z]{16})                           # AWS access key
(-----BEGIN (RSA |EC )?PRIVATE KEY-----)      # Private keys
mongodb(\+srv)?://[^:]+:[^@]+@               # MongoDB connection string
postgres(ql)?://[^:]+:[^@]+@                 # PostgreSQL connection string
```

**Scoring**:
- No secrets found: 30/30
- Potential false positive (e.g., example/test values): 20/30
- Confirmed secret pattern: 0/30 (blocks commit)

### Category 2: Injection Prevention (30 points)

**What to check**:
- SQL injection (string concatenation in queries)
- XSS (unescaped user input in HTML/templates)
- Command injection (user input in shell commands)
- Path traversal (user input in file paths)
- LDAP injection, XML injection, template injection

**Safe vs unsafe patterns**:

```javascript
// UNSAFE - SQL injection
db.query(`SELECT * FROM users WHERE id = ${userId}`);

// SAFE - Parameterized query
db.query('SELECT * FROM users WHERE id = $1', [userId]);

// UNSAFE - Command injection
exec(`ls ${userInput}`);

// SAFE - Avoid shell, use API
fs.readdir(sanitizedPath);

// UNSAFE - XSS
element.innerHTML = userInput;

// SAFE - Text content or sanitized
element.textContent = userInput;

// UNSAFE - Path traversal
fs.readFile(`/uploads/${filename}`);

// SAFE - Path validation
const safePath = path.resolve('/uploads', filename);
if (!safePath.startsWith('/uploads/')) throw new Error('Invalid path');
```

**Scoring**:
- No injection risks: 30/30
- Minor risk with mitigating context: 20/30
- Direct user input in dangerous sink: 0/30 (blocks commit)

### Category 3: Auth & Crypto (20 points)

**What to check**:
- Hardcoded credentials or default passwords
- Weak hashing algorithms (MD5, SHA1 for passwords)
- Insecure token generation (Math.random, predictable seeds)
- Missing authentication on sensitive endpoints
- Overly permissive CORS configuration

**Red flags**:
```javascript
// WEAK - MD5 for password hashing
crypto.createHash('md5').update(password);

// STRONG - bcrypt or argon2
await bcrypt.hash(password, 12);

// WEAK - Predictable token
const token = Math.random().toString(36);

// STRONG - Cryptographic randomness
const token = crypto.randomBytes(32).toString('hex');

// DANGEROUS - Wildcard CORS
app.use(cors({ origin: '*', credentials: true }));

// SAFE - Specific origins
app.use(cors({ origin: ['https://app.example.com'] }));
```

**Scoring**:
- No auth/crypto issues: 20/20
- Minor weakness with mitigating factors: 12/20
- Critical weakness (weak hashing, hardcoded creds): 0/20

### Category 4: Dependency Risk (20 points)

**What to check**:
- Known CVE patterns in dependency versions
- Outdated major versions with known vulnerabilities
- Typosquatting indicators (similar names to popular packages)
- Excessive permissions requested by dependencies
- Dependencies with no maintenance (archived, deprecated)

**Scoring**:
- No dependency risks detected: 20/20
- Minor version lag without known CVEs: 15/20
- Known CVE in dependency: 5/20
- Critical CVE or typosquatting: 0/20

## Validation Process

### Step 1: Scan Code Changes (< 10 seconds)

Analyze all files modified in the current implementation:
1. Read each changed file
2. Apply regex patterns for each category
3. Check against known vulnerability patterns
4. Flag any matches with severity and location

### Step 2: Contextual Analysis (< 10 seconds)

For each flag, determine if it's a real risk or false positive:
- Is the code in a test file? (lower severity)
- Is the "secret" an example/placeholder? (false positive)
- Is there sanitization before the dangerous sink? (mitigated)
- Is the code behind authentication? (reduced exposure)

### Step 3: Score and Report (< 5 seconds)

```markdown
## Security Validation Report

**Score: [X]/100**
**Status: PASS/FAIL** (threshold: 80)

### Secrets Detection: [X]/30
- [findings or "No issues found"]

### Injection Prevention: [X]/30
- [findings or "No issues found"]

### Auth & Crypto: [X]/20
- [findings or "No issues found"]

### Dependency Risk: [X]/20
- [findings or "No issues found"]

### Recommendations
- [actionable fixes for any issues found]
```

## Pass Threshold

**Score >= 80/100**: PASS - Proceed with commit
**Score < 80/100**: FAIL - Fix issues before committing

Any single category scoring 0 blocks the commit regardless of total score.

## Integration Points

- **Gate 3.5**: Runs between implementation completion and git commit
- Works with `brahma-analyzer` for cross-artifact consistency
- Reports feed into `pattern-recognition` for anti-pattern tracking

## Performance Target

Total validation time: < 25 seconds for typical code changes.
