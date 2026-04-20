// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  ConfidentialVote
 * @author labiletosky
 * @notice Privacy-first DAO governance — Prototype v1
 *
 *  Votes are committed as hashed values on-chain (commit-reveal scheme).
 *  No one can see how others voted until the reveal phase after the deadline.
 *  This prototype demonstrates the UX and architecture.
 *  Full FHE encryption via Zama fhEVM is implemented in v2.
 *
 *  Deployed on Ethereum Sepolia Testnet.
 */
contract ConfidentialVote {

    // ─── Structs ─────────────────────────────────────────────────────────────

    struct Proposal {
        string  title;
        string  description;
        address creator;
        uint256 deadline;
        uint32  yesCount;
        uint32  noCount;
        uint32  voterCount;
        bool    resultRevealed;
        bool    passed;
    }

    struct VoteCommit {
        bytes32 commitHash; // keccak256(vote + secret)
        bool    revealed;
        bool    vote;
    }

    // ─── State ───────────────────────────────────────────────────────────────

    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    // proposalId => voter => commit
    mapping(uint256 => mapping(address => VoteCommit)) public voteCommits;

    // ─── Events ──────────────────────────────────────────────────────────────

    event ProposalCreated(uint256 indexed id, string title, address indexed creator, uint256 deadline);
    event VoteCommitted(uint256 indexed proposalId, address indexed voter);
    event VoteRevealed(uint256 indexed proposalId, address indexed voter, bool vote);
    event ResultFinalized(uint256 indexed proposalId, bool passed, uint32 yes, uint32 no);

    // ─── Errors ──────────────────────────────────────────────────────────────

    error InvalidDuration();
    error NotFound();
    error VotingClosed();
    error VotingStillOpen();
    error AlreadyCommitted();
    error NoCommitFound();
    error AlreadyRevealed();
    error InvalidReveal();
    error AlreadyFinalized();

    // ─── Create Proposal ─────────────────────────────────────────────────────

    /**
     * @notice Create a new governance proposal.
     * @param title        Short title.
     * @param description  Full proposal description.
     * @param durationSecs Voting window in seconds (e.g. 300 = 5 min demo, 86400 = 1 day).
     */
    function createProposal(
        string calldata title,
        string calldata description,
        uint256 durationSecs
    ) external returns (uint256 id) {
        if (durationSecs == 0) revert InvalidDuration();

        id = proposalCount++;

        proposals[id] = Proposal({
            title:          title,
            description:    description,
            creator:        msg.sender,
            deadline:       block.timestamp + durationSecs,
            yesCount:       0,
            noCount:        0,
            voterCount:     0,
            resultRevealed: false,
            passed:         false
        });

        emit ProposalCreated(id, title, msg.sender, proposals[id].deadline);
    }

    // ─── Commit Vote ──────────────────────────────────────────────────────────

    /**
     * @notice Commit a hidden vote. Nobody can see how you voted until reveal.
     * @param proposalId Target proposal.
     * @param commitHash keccak256(abi.encodePacked(vote, secret)) — generated client-side.
     *
     * To generate commitHash off-chain:
     *   ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["bool","bytes32"],[true, secret]))
     */
    function commitVote(uint256 proposalId, bytes32 commitHash) external {
        Proposal storage p = proposals[proposalId];
        if (p.creator == address(0))                    revert NotFound();
        if (block.timestamp > p.deadline)               revert VotingClosed();
        if (voteCommits[proposalId][msg.sender].commitHash != bytes32(0)) revert AlreadyCommitted();

        voteCommits[proposalId][msg.sender] = VoteCommit({
            commitHash: commitHash,
            revealed:   false,
            vote:       false
        });

        p.voterCount++;
        emit VoteCommitted(proposalId, msg.sender);
    }

    // ─── Reveal Vote ──────────────────────────────────────────────────────────

    /**
     * @notice Reveal your vote after the deadline. Proves what you committed to.
     * @param proposalId Target proposal.
     * @param vote       Your actual vote (true = YES, false = NO).
     * @param secret     The secret bytes32 you used when committing.
     */
    function revealVote(uint256 proposalId, bool vote, bytes32 secret) external {
        Proposal storage p = proposals[proposalId];
        if (p.creator == address(0))          revert NotFound();
        if (block.timestamp <= p.deadline)    revert VotingStillOpen();
        if (p.resultRevealed)                 revert AlreadyFinalized();

        VoteCommit storage vc = voteCommits[proposalId][msg.sender];
        if (vc.commitHash == bytes32(0)) revert NoCommitFound();
        if (vc.revealed)                 revert AlreadyRevealed();

        // Verify the reveal matches the commit
        bytes32 expected = keccak256(abi.encodePacked(vote, secret));
        if (expected != vc.commitHash) revert InvalidReveal();

        vc.revealed = true;
        vc.vote     = vote;

        if (vote) {
            p.yesCount++;
        } else {
            p.noCount++;
        }

        emit VoteRevealed(proposalId, msg.sender, vote);
    }

    // ─── Finalize Result ──────────────────────────────────────────────────────

    /**
     * @notice Finalize and record the result after reveals are done.
     * @param proposalId Target proposal.
     */
    function finalizeResult(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (p.creator == address(0))       revert NotFound();
        if (block.timestamp <= p.deadline) revert VotingStillOpen();
        if (p.resultRevealed)              revert AlreadyFinalized();

        p.resultRevealed = true;
        p.passed         = p.yesCount > p.noCount;

        emit ResultFinalized(proposalId, p.passed, p.yesCount, p.noCount);
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getProposal(uint256 id) external view returns (
        string memory title,
        string memory description,
        address creator,
        uint256 deadline,
        uint32  voterCount,
        bool    resultRevealed,
        bool    passed
    ) {
        Proposal storage p = proposals[id];
        return (p.title, p.description, p.creator, p.deadline, p.voterCount, p.resultRevealed, p.passed);
    }

    function isVotingOpen(uint256 id) external view returns (bool) {
        Proposal storage p = proposals[id];
        return p.creator != address(0) && block.timestamp <= p.deadline;
    }

    function hasCommitted(uint256 proposalId, address voter) external view returns (bool) {
        return voteCommits[proposalId][voter].commitHash != bytes32(0);
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    /**
     * @notice Generate a commit hash on-chain for testing.
     *         In production, do this client-side so the secret stays private.
     */
    function generateCommitHash(bool vote, bytes32 secret) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(vote, secret));
    }
}
