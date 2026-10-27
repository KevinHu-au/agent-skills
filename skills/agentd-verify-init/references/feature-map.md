# Picking the features

Load this file in Flow step 3. It says how to pick about five features for the feature map. The engineer decides the final list.

## Find the features

List every feature a user can reach. Use three sources and note which one named each feature.

- Routes: the router table, route folders and page components.
- Menus: the navigation menu, tabs and any action menu a user opens.
- User documents: a user guide, help pages, release notes and screenshot folders. They use the words a user uses.

Merge the three lists. Two names for one screen are one feature. Always include the entry feature: the feature where a user opens or creates the main record. Every other feature needs a way to reach it from there, so a verifier can start from the entry feature.

## Rank

Rank the features by recent change. Count the merged pull requests, or the commits, that touched each feature's files over the last six months. This is churn. A feature with high churn breaks more often, so it needs a drive recipe first.

- Name the folders for each feature, then run `git log --since="6 months ago" --name-only` over them. Write the folders in the Code folders column of `features/README.md`.
- With no history (a shallow clone, or no git), rank by the size of the feature's code and mark the ranking `inferred:`.
- Break a tie with the feature that holds a calculation, a permission rule or a write to the database.

## Confirm

Show about five features. Give one reason for each: the churn count, the entry feature, or a calculation or permission rule. Put the entry feature first.

Ask the engineer to confirm, swap or add. They may know a feature that matters more than its churn says. Add every feature they name. Do not write a feature file for a feature the engineer left out.
