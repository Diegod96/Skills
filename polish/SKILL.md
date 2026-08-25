---
name: polish
description: Strip AI-generated tells from Salesforce documents and technical prose while protecting the conventions that make technical writing precise. Use this on any document headed for a human reader, including specs, feasibility assessments, impact maps, release notes, merge request descriptions, rollback plans, JIRA ticket bodies, and stakeholder emails. Use it whenever someone says "polish this", "make this sound less like AI", "clean up this writing", "tighten this up", or is about to send a generated document to a stakeholder. Do NOT apply it to Apex, LWC, flow XML, metadata, commit messages, or command output.
---

# Polish

Edit a document so it reads like a competent engineer wrote it rather than a language model. Two failure modes, not one. The obvious one is AI padding. The less obvious one is stripping so hard that the result is sterile and voiceless, which reads just as machine-generated.

The specific risk in this domain is over-application. Technical writing has conventions that resemble AI tells and are not. A polish pass that "fixes" them makes the document worse and, in the case of API names, factually wrong. Read the protected list before editing.

## Scope

Apply to prose that a human reads for meaning.

Do not apply to Apex, LWC, flow XML, metadata files, commit messages, branch names, command output, test results, log excerpts, or code comments. Do not apply to structured data inside a document, meaning tables, metadata inventories, acceptance criteria in Given/When/Then form, numbered procedural steps, and checklists. Those exist to be scanned and compared, not read.

The line is roughly: if a reader consumes it as sentences, polish it. If they consume it as a lookup table, leave it.

## Audience calibration

Voice differs by reader, and getting this wrong is more damaging than any individual word choice.

**Stakeholder documents** such as release notes and feasibility summaries go to people who do not know the platform. Use the labels they see in the UI, not API names. Lead with what they can do. Skip the mechanism unless it changes their behavior. Institutional voice, not blog voice, so no first person and no jokes unless the org already writes that way.

**Developer documents** such as specs, impact maps, and merge request descriptions go to people who know Salesforce but not this ticket. API names are correct and expected here. First person is fine in reviewer notes, where "I am unsure whether the before-save context is right here" is more useful than a passive construction that hides who is uncertain.

**Archival documents** such as technical changelogs and rollback plans get read in eighteen months by someone with no context. Favor precision over flow. Name things fully on first use. Assume the reader cannot ask a follow-up question.

## Cut these

**Significance inflation.** "This pivotal enhancement underscores our commitment to streamlining the donor experience." Nothing happened in that sentence. Say what changed.

**Promotional adjectives.** Seamless, robust, powerful, comprehensive, streamlined, cutting-edge. None of them describe anything a reader can act on. A spec that calls a solution "robust" is asserting a conclusion the reader was going to draw.

**Trailing -ing clauses.** "...improving data quality and enhancing reporting accuracy." These attach to the end of a sentence and add nothing. Either name the specific improvement with a number, or delete the clause.

**Vague attribution.** "Best practices suggest," "it is generally recommended," "Salesforce advises." Name the source, link the doc, or state it as your own judgment. Unattributed authority is how wrong things get repeated.

**Filler openers.** "It is important to note that," "it should be mentioned," "as previously discussed." Delete and start with the content.

**Stacked hedging.** "This could potentially cause issues in some cases" reduces to "this may fail" plus the condition under which it fails. One hedge, then the specific circumstance.

**Generic closings.** "This change positions the team for continued success." Cut it or replace with the actual next step.

**Chatbot residue.** "Great question," "I hope this helps," "Let me know if you need anything else," "Certainly." None of these belong in a document.

**Inflated verbs.** Utilize becomes use. Leverage becomes use. Facilitate becomes help or let. Ensure becomes make sure, or name the mechanism that guarantees it. Delve becomes look at.

**The not-just-X construction.** "This is not just a field addition, it is a rethinking of how we track engagement." State the claim directly or drop it.

**Buried actors in passive voice.** "The records are updated by the flow" becomes "the flow updates the records." Passive hides who acts, and in a technical document, who acts is usually the point.

## Protect these

Each of these resembles a tell and is correct here. Do not edit them out.

**Repeating an exact term.** Synonym variation is a virtue in narrative prose and a defect in technical writing. `Opportunity__c` is `Opportunity__c` on every mention. Never soften it to "the opportunity object," "the record," or "the custom object" for variety. Ambiguity about which thing is being discussed costs more than repetition.

**Passive voice with no meaningful actor.** "The record is locked during approval" is correct. The actor is the platform, naming it adds nothing, and the reader cares about the state.

**Hedging that reflects real uncertainty.** "This may fail depending on the order of execution" is not weak writing. It is an accurate statement about a genuinely non-deterministic situation. Compressing it to "this will fail" is a factual error. Cut hedges that pad. Keep hedges that report.

**Lists of three when there are three things.** Forcing a triad is a tell. Having three items is arithmetic.

**Bold labels in tables and structured lists.** In a metadata inventory or a findings list, the bold label is a scanning aid. It becomes a tell only when the label restates the sentence that follows it, as in "**Coverage:** Coverage improved to 88%."

**Formal register in stakeholder communication.** Institutional documents are supposed to sound institutional. Injecting personality into a message going to several hundred staff is a different error, not a fix.

**Caveats and known limitations.** A spec that says what it does not cover is doing its job. Do not trim these for concision.

## Give it a voice

Removing patterns is half of it. What is left has to sound like someone with judgment wrote it.

**Take positions.** "Both approaches are viable, each with tradeoffs" is a non-answer. "Flow is the better fit here because the logic is simple enough that an admin should be able to maintain it" is a recommendation. When there is a real recommendation, make it and defend it in one sentence.

**Be concrete.** "This improves performance" becomes "this removes the query from the loop, so a 200-record load runs one query instead of 200." A number or a mechanism beats an adjective every time.

**Vary sentence length.** Several medium-length sentences in a row is the most reliable rhythm tell there is. Break one. Then let the next one run longer, because the idea it carries genuinely needs the room.

**Say the uncomfortable thing.** "I am not confident the before-save context is right here" and "we shipped this without a bulk test because of the deadline" are the most valuable sentences in most technical documents. Generated prose smooths them away.

**Let structure be uneven.** Every section the same length with the same number of bullets reads as generated. Some points need a paragraph. Some need a clause.

## On em dashes

Worth deciding as a team rather than absorbing by default. The strict position is that em dashes are an AI tell and should be avoided outright. The moderate position, and the one this skill takes, is that the tell is frequency rather than existence. One per few paragraphs reads as ordinary punctuation. Three in a paragraph reads as generated, and swapping them all for parentheses just trades one tell for another.

If the team prefers the strict rule, change this section and the skill enforces it. This document is written without em dashes, so the constraint is workable if you want it.

## Process

1. Read the whole document once before editing. Local edits that fight the document's purpose are worse than no edits.
2. Identify the audience and set the register accordingly.
3. Mark the structured regions to leave alone, meaning tables, checklists, code, acceptance criteria.
4. Cut the patterns above from the prose.
5. Check the protected list. Restore anything the cutting pass damaged, especially inconsistent API names.
6. Read it aloud, or at least subvocalize. Rhythm problems surface here that do not surface on the page.
7. Self-audit with one question: if someone told me this was AI generated, what would I point to? Fix that.

## Report the edits

When polishing a document someone else wrote or generated, note anything cut that carried meaning rather than just padding. A hedge removed, a caveat trimmed, a recommendation sharpened past what the evidence supports. Silent edits to a technical document can change what it claims, and the author should get to review that.
