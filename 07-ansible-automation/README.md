# 07 — Ansible Automation (z/OSMF REST)

Driving a z/OS assembler build from **Ansible** through the **z/OSMF REST
API** — submit the compile/link JCL, poll the job to completion, and pull
back its output — so mainframe assembly fits into the same automation
tooling as the rest of an estate. The DevOps-on-z/OS counterpart to the
hand-run JCL in the other artifacts.

## Purpose

Show that a traditional HLASM assemble/link can be invoked, monitored, and
reported on without manual JES interaction: one `ansible-playbook` run does
upload → submit → wait → fetch output → record a summary, and fails the
play if the job's return code is not clean.

## How it works

`playbooks/compile_assembler.yml` talks to z/OSMF over REST (`ansible.
builtin.uri`):

1. Upload the compile JCL to USS (`/zosmf/restfiles/fs…`).
2. Submit it as a job (`PUT /zosmf/restjobs/jobs`).
3. Poll the job until `status == OUTPUT` (`until/retries/delay`).
4. Retrieve the job's spool files and echo `SYSTSPRT` / `JESMSGLG`.
5. Write a summary to `workflows/last_compile_info.txt` and **fail the
   play** unless the return code is `CC 0000` (or `CC 0004`).

The JCL itself (`jcl/COMPASM.jcl`) invokes the site COMPILE CLIST to
assemble and link-edit the target member.

## Files

| File | What it is |
|------|------------|
| `playbooks/compile_assembler.yml` | The playbook — REST submit/poll/report. |
| `jcl/COMPASM.jcl` | Compile/link JCL (invokes the COMPILE CLIST). |
| `scripts/compile-asm.sh` | Convenience wrapper to run the playbook. |
| `scripts/sync-and-run.sh` | Sync files into WSL and run. |
| `QUICKSTART.md` / `docs/DESIGN.md` | Setup and architecture. |

## Running it

```bash
export ZOS_PASSWORD='…'          # credentials come from the environment
cd 07-ansible-automation/scripts
bash compile-asm.sh
```

Connection settings (z/OSMF host/port/user) live in the playbook `vars`;
the password is read from `$ZOS_PASSWORD`, never stored in the repo.
Designed to run from Linux or Windows via WSL.

## Skills demonstrated

- z/OSMF REST API: REST file upload, job submit, status polling, and
  spool-file retrieval.
- Ansible orchestration of a mainframe build with return-code gating and a
  recorded run summary.
- Keeping credentials out of source (environment-supplied password).

> Note: this artifact's playbook talks to z/OSMF directly with
> `ansible.builtin.uri`. A more production-grade path is the IBM
> `ibm.ibm_zosmf` collection (`zmf_workflow*`); that approach is explored
> separately in the workspace's `ansible-zosmf/` work.
