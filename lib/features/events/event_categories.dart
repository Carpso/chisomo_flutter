/// Curated EVENT categories — events are NOT fundraisers, so they get their own
/// distinct category set so the two never mix. Kept in sync with the backend
/// `EVENT_CATEGORIES` in src/categories.ts (the API validates against its copy).
const kEventCategories = [
  'Other',
  'Concert & Worship Night',
  'Conference & Seminar',
  'Gala & Fundraising Dinner',
  'Church Service & Revival',
  'Community Gathering',
  'Charity Run & Walk',
  'Sports Tournament',
  'Youth Event',
  "Children's Event",
  'Workshop & Training',
  'Auction & Sale',
  'Movie & Talent Show',
  'Networking & Mixer',
  'Outreach & Missions Trip',
  'Festival & Fair',
  'Wedding & Celebration',
  'Memorial & Tribute',
  'Expo & Trade Show',
];

/// Alphabetical event category list for dropdowns ('Other' stays first).
final List<String> kSortedEventCategories = [
  'Other',
  ...(kEventCategories.where((c) => c != 'Other').toList()..sort()),
];
