module gdrive.test.live.integration;

version (GDriveTestLive)
{
    import gdrive : File, Folder, Identity, Session;
    import gdrive.test.live.utils : assertExpectedIdentity, liveTestFolderName,
        makeLiveSession, recreateTestRoot;

    private bool hasFolderNamed(Folder[] folders, string name)
    {
        foreach (Folder folder; folders)
        {
            if (folder.name == name)
                return true;
        }

        return false;
    }

    private bool hasFileNamed(File[] files, string name)
    {
        foreach (File file; files)
        {
            if (file.name == name)
                return true;
        }

        return false;
    }

    @system unittest
    {
        Session session = makeLiveSession();
        Identity identity = session.login();
        scope (exit) identity.logout();

        assertExpectedIdentity(identity);

        Folder root = recreateTestRoot(identity);
        assert(root.name == liveTestFolderName);
        assert(root.id != null);

        Folder childFolder = root.create(new Folder(identity, "child-folder"));
        File rootFile = root.create(new File(identity, "root.txt", "text/plain"));
        rootFile.write(cast(const(ubyte)[])"root-data".dup);

        File draftFile = new File(
            identity,
            "draft.txt",
            "text/plain",
            root.id,
        );
        assert(draftFile.read() is null);
        draftFile.write(cast(const(ubyte)[])"draft-data".dup);

        File childFile = childFolder.create(new File(identity, "child.txt", "text/plain"));
        childFile.write(cast(const(ubyte)[])"child-data".dup);

        assert(hasFolderNamed(identity.folders(), liveTestFolderName));

        root.refresh();
        assert(hasFolderNamed(root.folders(), "child-folder"));
        assert(hasFileNamed(root.files(), "root.txt"));
        assert(hasFileNamed(root.files(), "draft.txt"));
        assert(rootFile.read() == cast(ubyte[])"root-data");
        assert(draftFile.read() == cast(ubyte[])"draft-data");

        childFolder.refresh();
        assert(hasFileNamed(childFolder.files(), "child.txt"));
        assert(childFile.read() == cast(ubyte[])"child-data");

        File deletedFile = root.create(new File(identity, "deleted.txt", "text/plain"));
        deletedFile.write(cast(const(ubyte)[])"deleted-data".dup);
        identity.remove(deletedFile);
        assert(deletedFile.read() is null);
    }
}
