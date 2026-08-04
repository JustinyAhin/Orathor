# OpenAI Live Transcribe evaluation

This is a manual QA record for `gpt-live-transcribe`. It deliberately contains no claimed live observations: this implementation run did not use an OpenAI API key or microphone audio.

| Scenario | Expected | Status | Observation / follow-up |
|---|---|---|---|
| Representative English | Accurate live deltas and matching final commit | Pending | Requires API key and microphone input. |
| Automatic language | `languages` omitted; accurate live transcription | Pending | Requires API key and microphone input. |
| One expected language | Payload sends `languages: [code]` | Pending live QA | Covered by automated payload test; verify recognition. |
| Multiple expected languages | Payload sends ordered `languages` array | Pending live QA | Covered by automated payload test; verify multilingual/code-switching speech. |
| Technical vocabulary | Prompt and keywords improve literal technical terms | Pending live QA | Covered by automated payload test; do not record sensitive hint content in diagnostics. |
| Negative keyword | An unspoken hinted term is not inserted | Pending live QA | Compare the same recording with and without the hint. |
| Short utterance | Delta and completed text remain complete without duplication | Pending live QA | Use a representative one- or two-word phrase. |
| Empty recording | Commit error is harmless and recording stops | Pending live QA | Requires a live socket; lifecycle behavior is not unit-tested. |
| Background noise | Final transcript remains complete and provider errors remain visible | Pending live QA | Use representative microphone and ambient noise. |
| Final transcript | Completed event replaces delta and preserves item order | Pending live QA | Covered by automated assembler tests. |
| Invalid keyword | Angle brackets or line breaks block connection with user-visible error | Pending UI QA | Covered by automated context test. |
| Warm socket | Pings every 15s; closes after 120s idle | Pending live QA | Requires network inspection and repeated dictation. |
| Connection/server error | Error includes provider code and message; stop resolves once | Pending live QA | Automated coverage verifies error formatting only; verify lifecycle behavior live. |
