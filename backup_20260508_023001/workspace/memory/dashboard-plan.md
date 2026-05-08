# Memory Dashboard Plan for brain.ecomunivers.cloud

## Goal
Create a submenu/dashboard on brain.ecomunivers.cloud that displays:
- Daily memory logs in an organized, searchable format
- Quick access to recent discussions and decisions
- Project/tag-based filtering
- Calendar view of activities
- Statistics and insights

## Proposed Structure

### 1. Data Layer
- Continue using `memory/YYYY-MM-DD.md` files as source
- Add metadata to each log file (YAML frontmatter or JSON header)
- Consider creating a memory index JSON for faster lookup

### 2. Next.js Implementation (in brain app)

#### Pages/Components:
- `/app/memory/page.tsx` - Main memory dashboard
- `/app/memory/[date]/page.tsx` - Daily log view
- `/app/memory/search/page.tsx` - Search interface
- `/app/memory/tags/[tag]/page.tsx` - Tag-based view
- `/app/memory/stats/page.tsx` - Analytics and statistics

#### Components:
- `MemoryCalendar` - Calendar view showing days with logs
- `MemoryList` - List of daily logs with summaries
- `MemorySearchBar` - Full-text search across logs
- `MemoryTagCloud` - Visual tag frequency display
- `MemoryStats` - Charts showing activity over time
- `DailyLogViewer` - Rendered view of a specific day's log

### 3. Features to Implement

#### Core Features:
- [ ] Daily log browsing (by date)
- [ ] Full-text search across all logs
- [ ] Tag-based filtering (extract tags from logs)
- [ ] Calendar heatmap view
- [ ] Recent activity sidebar
- [ ] Export functionality (PDF/Markdown)

#### Enhanced Features:
- [ ] Automatic summarization of long logs
- [ ] Entity extraction (people, projects, decisions)
- [ ] Timeline view of discussions
- [ ] Cross-referencing between related days
- [ ] Mood/activity tracking (if logged)

### 4. Implementation Steps

#### Phase 1: Basic Display
1. Create API route to read memory files
2. Build main dashboard with calendar and list views
3. Create daily log viewer component
4. Add basic search functionality

#### Phase 2: Enhanced Features
1. Add tag extraction and filtering
2. Implement statistics and charts
3. Add export capabilities
4. Improve UI/UX with better styling

#### Phase 3: Intelligence
1. Add automatic summarization
2. Implement entity recognition
3. Create smart cross-referencing
4. Add insights generation

### 5. Technical Details

#### File Format Enhancement
Consider adding YAML frontmatter to daily logs:
```yaml
---
date: 2026-03-22
tags: [heartbeat, backup, memory-system]
projects: [memory-dashboard, brain-integration]
summary: "Set up daily memory system and discussed brain dashboard integration"
---

# Memory for 2026-03-22
...
```

#### API Routes Needed
- `GET /api/memory/logs` - List all available logs
- `GET /api/memory/logs/[date]` - Get specific log
- `GET /api/memory/search?q=` - Search logs
- `GET /api/memory/tags` - Get all tags with frequency
- `GET /api/memory/stats` - Get activity statistics

### 6. Integration with Existing Systems
- Link from brain dashboard main menu
- Respect existing authentication if any
- Maintain consistent styling with brain theme
- Ensure mobile responsiveness

### 7. Next Steps (when permissions allow)
1. Create the basic file structure in brain app
2. Implement API routes for memory access
3. Build core dashboard components
4. Test with existing memory logs
5. Deploy to brain.ecomunivers.cloud

## Current Status
Permission issues prevent direct access to brain directory and execution of commands. However, the memory logging system is working in the workspace. This plan can be implemented once access is restored, or files can be created in workspace and moved later.

## Immediate Actions (within current constraints)
- Continue maintaining daily logs in workspace/memory/
- Consider creating a simple static dashboard in workspace that could be integrated later
- Document the desired structure for future implementation