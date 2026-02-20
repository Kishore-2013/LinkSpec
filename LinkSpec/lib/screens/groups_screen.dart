import 'package:flutter/material.dart';
import '../models/group.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<Group> _groups = [
    Group(
      id: '1',
      name: 'Medical Professionals Network',
      description: 'A group for doctors, nurses, and medical students to share insights.',
      memberCount: '1.2k',
      domainId: 'Medical',
      coverUrl: 'https://images.unsplash.com/photo-1576091160550-217359f4810a?q=80&w=2070&auto=format&fit=crop',
    ),
    Group(
      id: '2',
      name: 'Digital Health Innovation',
      description: 'Exploring the intersection of technology and healthcare.',
      memberCount: '850',
      domainId: 'Medical',
      coverUrl: 'https://images.unsplash.com/photo-1504868584819-f8e905263543?q=80&w=2076&auto=format&fit=crop',
    ),
    Group(
      id: '3',
      name: 'Future Surgeons',
      description: 'Connecting aspiring surgeons and sharing educational resources.',
      memberCount: '3.4k',
      domainId: 'Medical',
      coverUrl: 'https://images.unsplash.com/photo-1551076805-e1869033e561?q=80&w=1932&auto=format&fit=crop',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Groups', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildYourGroupsHeader(),
            _buildGroupsList(),
            _buildDiscoverHeader(),
            _buildDiscoverGroupsList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create Group feature coming soon!')),
          );
        },
        label: const Text('Create'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildYourGroupsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        'Your Groups',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildDiscoverHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        'Discover Groups',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildDiscoverGroupsList() {
    // Mocking some discovery groups
    final discoverGroups = [
      Group(
        id: '4',
        name: 'AI in Healthcare',
        description: 'Discussing the latest in AI and machine learning for health.',
        memberCount: '5.2k',
        domainId: 'Medical',
        coverUrl: 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?q=80&w=2070&auto=format&fit=crop',
      ),
      Group(
        id: '5',
        name: 'Nurse Educators',
        description: 'A place for those teaching the next generation of nurses.',
        memberCount: '2.1k',
        domainId: 'Medical',
        coverUrl: 'https://images.unsplash.com/photo-1516549655169-df83a0774514?q=80&w=2070&auto=format&fit=crop',
      ),
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: discoverGroups.length,
      itemBuilder: (context, index) {
        final group = discoverGroups[index];
        return _buildGroupCard(group, isDiscover: true);
      },
    );
  }

  Widget _buildGroupCard(Group group, {bool isDiscover = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          // Future: Navigate to group details
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.coverUrl != null)
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  image: DecorationImage(
                    image: NetworkImage(group.coverUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.groups, color: Colors.blue, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.memberCount} members',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          group.description,
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isDiscover)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Join Group'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
