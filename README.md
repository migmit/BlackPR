# BlackPR

## Downloads

Current release: https://github.com/migmit/BlackPR/releases/latest/download/BlackPR.dmg

## FAQ

- Q: Why does this program requests access to my code? What is it going to commit?

  A: It won't commit anything. Unfortunately, GitHub does not, at this point, offer an option to request access to pull requests only, or even a read-only access.

- Q: Why does this program access something on Amazon? Does it store my personal data somewhere?

  A: No, it does not. Unfortunately, GitHub authorization process is not really fit for desktop apps, which is why this app needs a AWS-hosted proxy. It's a stateless lambda function.

- Q: What happens if that Amazon website goes down?

  A: You won't be able to add new GitHub logins. However, the old ones, already added, would continue to work, as the website is only used during initial setup.

- Q: I've added myself as a reviewer, or reopened an erroneously closed pull request, but can't see that change in this program. Why is that?

  A: GitHub does not, at this moment, have a reliable way for this program to know about that request. If somebody else requests a review — not necessarily the author of the pull request — then you'd see it in the program; but not if you do it yourself. However, some activity on the request might eventually bring it to the program's attention. Same thing applies if you've reopened a PR that you were requested to review — this program can't detect that it was opened.

- Q: Some issue prevented the program from noticing that something changed about a pull request — for example, it's title. Will it be stuck forever?

  A: If the pull request still needs your attention, then no, it would be updated — normally within 10 seconds. If not, there is a good chance it would be stuck. You can refresh it manually by right-clicking on it in the program.

- Q: Some old pull request was approved or rejected, but the program shows it as not having any reviews. Why is that?

  A: It's a GitHub bug. Sometimes it loses information about reviews of old pull requests. Manual refreshing, unfortunately, won't help. There isn't anything that can be done. Not sure yet how old that pull request should be.

- Q: Can this program be used for tracking pull requests on private GitHub instances, GitLab, BitBucket, or something else?

  A: No, not at the moment. This is one of the features that probably would be added in the future. Stay tuned.

- Q: Can I get this program from App Store?

  A: Not yet, working on it.

- Q: I have a pull request into this very repository. How soon would you get around to review it?

  A: Most likely, unless you know me personally, you should wait until the heat death of the universe.

- Q: Those notifications are super annoying! Can I turn them off?

  A: It's macOS, you can turn off notifications from any program, not just this one. Just go to System Preferences -> Notifications. Note that there is a separate checkbox there for an application badge — you might want to leave it as it is.\

- Q: App's window just stays on my desktop — can I remove it, while still working with the app?

  A: Sure, just use macOS "Hide" feature — basically, press Cmd+H, and it will go away.
